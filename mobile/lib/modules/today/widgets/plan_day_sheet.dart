import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../onboarding/widgets/pipeda_note.dart';
import '../day_plans_controller.dart';
import '../models/day_plan.dart';
import 'outfit_card.dart';

/// What the sheet hands back: a plan to save, or a clear — each with the
/// days it applies to.
sealed class _PlanResult {
  const _PlanResult();
}

class _Saved extends _PlanResult {
  final DayPlan plan;
  final DayPlanScope scope;
  const _Saved(this.plan, this.scope);
}

/// "Repeat every …" switched off on a repeating day: stop the repeat, keep
/// this day's plan.
class _SavedStopRepeat extends _PlanResult {
  final DayPlan plan;
  const _SavedStopRepeat(this.plan);
}

class _Cleared extends _PlanResult {
  final DayPlanScope scope;
  const _Cleared(this.scope);
}

/// Plan the day (Stitch `plan_the_day_thursday_nov_5`): what's on (one of 12
/// occasions), how dressed up (5 stops, defaulted by the occasion), a note,
/// repeat-weekly, then Save. Saves go through [dayPlansProvider] to
/// `/today/plans`; on a day a repeat covers, Save and Clear ask "just this
/// one, or every one?" first.
class PlanDaySheet extends StatefulWidget {
  final DateTime date;
  final DayPlan? existing;

  /// A weekly repeat covers this day (planned, or cleared just this once).
  final bool repeats;

  /// e.g. "6°C · Rain" — only known for today until the frame carries a
  /// forecast; hidden when null.
  final String? weatherLabel;
  final IconData? weatherIcon;

  const PlanDaySheet({
    super.key,
    required this.date,
    this.existing,
    this.repeats = false,
    this.weatherLabel,
    this.weatherIcon,
  });

  /// Opens the sheet for [date], saves the result, and confirms with a toast
  /// ("Planned: Work day, Thursday…") — with Undo when the day can be put
  /// back exactly.
  static Future<void> open(
    BuildContext context,
    WidgetRef ref,
    DateTime date, {
    String? weatherLabel,
    IconData? weatherIcon,
  }) async {
    final controller = ref.read(dayPlansProvider.notifier);
    final previous = controller.planFor(date);
    final messenger = ScaffoldMessenger.of(context);
    final result = await AppBottomSheet.show<_PlanResult>(
      context,
      builder: (_) => PlanDaySheet(
        date: date,
        existing: previous,
        repeats: controller.repeats(date),
        weatherLabel: weatherLabel,
        weatherIcon: weatherIcon,
      ),
    );
    if (result == null) return;

    final weekday = weekdayLong(date);
    final String message;
    var undoable = false;
    try {
      switch (result) {
        case _Saved(:final plan, scope: DayPlanScope.day):
          await controller.save(plan);
          message = _plannedMessage(plan);
          undoable = controller.canRestore(previous);
        case _Saved(:final plan, scope: DayPlanScope.fromNow):
          await controller.save(plan, scope: DayPlanScope.fromNow);
          message = 'Planned: ${plan.occasion.label}, every $weekday.';
        case _SavedStopRepeat(:final plan):
          await controller.stopRepeatAndSave(plan);
          message =
              'Planned: ${plan.occasion.label}, ${_dayName(date)}. '
              '$weekday repeat stopped.';
        case _Cleared(scope: DayPlanScope.day):
          await controller.clear(date);
          message = 'Plan cleared for ${_dayName(date)}.';
          undoable = controller.canRestore(previous);
        case _Cleared(scope: DayPlanScope.fromNow):
          await controller.clear(date, scope: DayPlanScope.fromNow);
          message = '$weekday repeat stopped.';
      }
    } on ApiException catch (e) {
      _toast(messenger, e.message);
      return;
    }
    _toast(
      messenger,
      message,
      onUndo: undoable
          ? () => controller
                .restore(date, previous)
                .catchError(
                  (Object e) => _toast(
                    messenger,
                    e is ApiException ? e.message : 'Could not undo that.',
                  ),
                )
          : null,
    );
  }

  static void _toast(
    ScaffoldMessengerState messenger,
    String message, {
    VoidCallback? onUndo,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.espressoDeep,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 5),
          action: onUndo == null
              ? null
              : SnackBarAction(
                  label: 'Undo',
                  textColor: AppColors.white,
                  onPressed: onUndo,
                ),
        ),
      );
  }

  static String _dayName(DateTime date) =>
      daysFromToday(date) == 0 ? 'today' : weekdayLong(date);

  static String _plannedMessage(DayPlan plan) {
    final head = 'Planned: ${plan.occasion.label}, ${_dayName(plan.date)}.';
    return switch (daysFromToday(plan.date)) {
      <= 0 => head,
      1 => '$head Your outfit will be ready by 10 pm.',
      _ => '$head Your outfit will be ready the evening before.',
    };
  }

  @override
  State<PlanDaySheet> createState() => _PlanDaySheetState();
}

class _PlanDaySheetState extends State<PlanDaySheet> {
  static const _noteMax = 100;

  DayOccasion? _occasion;
  late DressLevel _dress;

  // Answering a question brings the next one into view.
  final _dressKey = GlobalKey();
  final _noteKey = GlobalKey();
  late final TextEditingController _note;
  late bool _repeat;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _occasion = e?.occasion;
    _dress = e?.dress ?? DressLevel.smartCasual;
    _note = TextEditingController(text: e?.note ?? '')
      ..addListener(() => setState(() {}));
    _repeat = widget.repeats;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _pickOccasion(DayOccasion o) {
    final picked = _occasion != o;
    setState(() {
      // Single choice; tapping the selected tile again unselects it.
      if (picked) {
        _occasion = o;
        _dress = o.dress; // the occasion's default; the slider overrides
      } else {
        _occasion = null;
      }
    });
    if (picked) _reveal(_dressKey);
  }

  void _pickDress(DressLevel d) {
    setState(() => _dress = d);
    _reveal(_noteKey);
  }

  /// Scrolls [key]'s section to the top of the sheet after this frame.
  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  Future<void> _save() async {
    final o = _occasion;
    if (o == null) return;
    final plan = DayPlan(
      date: widget.date,
      occasion: o,
      dress: _dress,
      note: _note.text.trim(),
    );
    final _PlanResult result;
    if (!widget.repeats) {
      // No repeat yet: the switch decides.
      result = _Saved(plan, _repeat ? DayPlanScope.fromNow : DayPlanScope.day);
    } else if (!_repeat) {
      result = _SavedStopRepeat(plan);
    } else {
      final scope = await _RepeatScopeSheet.ask(
        context,
        widget.date,
        clearing: false,
      );
      if (scope == null || !mounted) return; // back to the sheet, edits kept
      result = _Saved(plan, scope);
    }
    if (mounted) Navigator.of(context).pop(result);
  }

  Future<void> _clear() async {
    var scope = DayPlanScope.day;
    if (widget.repeats) {
      final picked = await _RepeatScopeSheet.ask(
        context,
        widget.date,
        clearing: true,
      );
      if (picked == null || !mounted) return;
      scope = picked;
    }
    if (mounted) Navigator.of(context).pop(_Cleared(scope));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = widget.date;
    final weekday = weekdayLong(date);
    // The shared sheet: grabber, 80% height, scrolling body (every section
    // built, so answering can scroll the next one into view), fixed footer.
    return AppBottomSheet(
      actions: _actions(text),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(text, date),
          const SizedBox(height: 24),
          _sectionLabel(text, 'What is on'),
          const SizedBox(height: 10),
          _occasionGrid(),
          const SizedBox(height: 28),
          KeyedSubtree(
            key: _dressKey,
            child: _sectionLabel(text, 'How dressed up?'),
          ),
          const SizedBox(height: 10),
          _DressSlider(value: _dress, onChanged: _pickDress),
          const SizedBox(height: 28),
          Row(
            key: _noteKey,
            children: [
              Expanded(
                child: Text(
                  'Anything else?',
                  style: text.titleSmall?.copyWith(color: AppColors.ink),
                ),
              ),
              Text(
                '${_note.text.length} / $_noteMax',
                style: text.bodySmall?.copyWith(color: AppColors.taupe),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _noteField(text),
          const SizedBox(height: 28),
          _repeatRow(text, weekday),
          if (widget.existing != null) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: _clear,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.error,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  'Clear plan',
                  style: text.labelLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _header(TextTheme text, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                '${weekdayLong(date)}, ${monthShort(date)} ${date.day}',
                style: text.headlineSmall?.copyWith(
                  color: AppColors.espressoDark,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  // Cormorant's default old-style figures make "14" read "I4".
                  fontFeatures: const [FontFeature.liningFigures()],
                ),
              ),
            ),
            // Always on the right: today's real weather, or a muted
            // placeholder until the frame carries a daily forecast.
            ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ivoryWarm,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.weatherIcon ?? Icons.cloud_outlined,
                      size: 14,
                      color: widget.weatherLabel == null
                          ? AppColors.taupe
                          : AppColors.inkSoft,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.weatherLabel ?? 'Forecast soon',
                      style: text.labelMedium?.copyWith(
                        color: widget.weatherLabel == null
                            ? AppColors.taupe
                            : AppColors.inkSoft,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'What is on your day? We will style your outfit to match.',
          style: text.bodyMedium,
        ),
      ],
    );
  }

  Widget _sectionLabel(TextTheme text, String label) => Text(
    label.toUpperCase(),
    style: text.labelMedium?.copyWith(
      color: AppColors.inkSoft,
      letterSpacing: 1.2,
    ),
  );

  Widget _occasionGrid() {
    const all = DayOccasion.values;
    return Column(
      children: [
        for (var r = 0; r < all.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var c = 0; c < 2; c++) ...[
                if (c > 0) const SizedBox(width: 8),
                Expanded(
                  child: r + c < all.length
                      ? _OccasionTile(
                          occasion: all[r + c],
                          selected: _occasion == all[r + c],
                          onTap: () => _pickOccasion(all[r + c]),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _noteField(TextTheme text) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: todayCardShadow,
      ),
      child: TextField(
        controller: _note,
        maxLength: _noteMax,
        maxLines: 3,
        minLines: 3,
        textCapitalization: TextCapitalization.sentences,
        style: text.bodyMedium?.copyWith(color: AppColors.ink),
        decoration: InputDecoration(
          hintText: 'e.g. outdoors, lots of walking, chilly room',
          hintStyle: text.bodyMedium?.copyWith(color: AppColors.taupeSoft),
          counterText: '', // the "0 / 100" above replaces it
          contentPadding: const EdgeInsets.all(14),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.sage),
          ),
        ),
      ),
    );
  }

  Widget _repeatRow(TextTheme text, String weekday) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: todayCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Repeat every $weekday',
                  style: text.titleSmall?.copyWith(color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Use this as your $weekday default',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _repeat,
            activeTrackColor: AppColors.espresso,
            onChanged: (v) => setState(() => _repeat = v),
          ),
        ],
      ),
    );
  }

  /// Save plan, with the privacy line under it (the sheet's footer slot).
  Widget _actions(TextTheme text) {
    final enabled = _occasion != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: enabled
                  ? const [AppColors.espressoDark, AppColors.espresso]
                  : const [AppColors.taupeSoft, AppColors.taupeSoft],
            ),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x33512F1B),
                      blurRadius: 16,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: enabled ? _save : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 52,
                child: Center(
                  child: Text(
                    'Save plan',
                    style: text.titleMedium?.copyWith(color: AppColors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        // The privacy line sits under the CTA, as in onboarding, with
        // breathing room between them.
        const SizedBox(height: 12),
        const PipedaNote(),
      ],
    );
  }
}

class _OccasionTile extends StatelessWidget {
  final DayOccasion occasion;
  final bool selected;
  final VoidCallback onTap;

  const _OccasionTile({
    required this.occasion,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 64,
        decoration: BoxDecoration(
          color: selected ? AppColors.ivoryDim : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.espresso : Colors.transparent,
            width: 2,
          ),
          boxShadow: todayCardShadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Stack(
              // Fill the 64dp tile so the icon + label centre vertically.
              fit: StackFit.expand,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
                  child: Row(
                    children: [
                      Icon(occasion.icon, size: 24, color: AppColors.espresso),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          occasion.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w500,
                                height: 1.2,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 5-stop "How dressed up?" slider: dotted track, ringed thumb, tappable
/// labels underneath.
class _DressSlider extends StatelessWidget {
  final DressLevel value;
  final ValueChanged<DressLevel> onChanged;
  const _DressSlider({required this.value, required this.onChanged});

  /// The slider's track starts/ends this far in from its edges (Flutter's
  /// track shape insets by the overlay radius). Pinned here so the labels
  /// can be centred under the stops with the same geometry. 30 (not the
  /// default 24) leaves room for "Athleisure" / "Formal" to centre under the
  /// end stops without spilling past the card.
  static const _trackInset = 30.0;

  @override
  Widget build(BuildContext context) {
    const levels = DressLevel.values;
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: todayCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 6,
              activeTrackColor: AppColors.espresso,
              inactiveTrackColor: AppColors.sand,
              activeTickMarkColor: AppColors.espresso,
              inactiveTickMarkColor: AppColors.taupeSoft,
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 4),
              thumbShape: const _RingThumbShape(),
              overlayShape: const RoundSliderOverlayShape(
                overlayRadius: _trackInset,
              ),
              overlayColor: AppColors.espresso.withValues(alpha: 0.08),
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              value: value.index.toDouble(),
              min: 0,
              max: (levels.length - 1).toDouble(),
              divisions: levels.length - 1,
              semanticFormatterCallback: (v) => levels[v.round()].label,
              onChanged: (v) => onChanged(levels[v.round()]),
            ),
          ),
          // Each label is centred exactly under its stop: same width as the
          // slider, same inset, one stop-spacing wide.
          LayoutBuilder(
            builder: (context, constraints) {
              final step =
                  (constraints.maxWidth - 2 * _trackInset) /
                  (levels.length - 1);
              return SizedBox(
                height: 18,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final (i, l) in levels.indexed)
                      Positioned(
                        left: _trackInset + step * i - step / 2,
                        width: step,
                        top: 0,
                        bottom: 0,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(l),
                          // One line: "Smart casual" shrinks a touch on
                          // narrow phones rather than wrapping.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              l.label,
                              maxLines: 1,
                              textAlign: TextAlign.center,
                              // The selected stop is the highlight (no
                              // separate pill): bold espresso; the rest
                              // muted. Same size so nothing reflows.
                              style: text.labelSmall?.copyWith(
                                fontSize: 11,
                                letterSpacing: 0,
                                color: l == value
                                    ? AppColors.espressoDark
                                    : AppColors.taupe,
                                fontWeight: l == value
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RingThumbShape extends SliderComponentShape {
  const _RingThumbShape();

  static const _radius = 12.0;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) =>
      const Size.fromRadius(_radius);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final canvas = context.canvas;
    canvas.drawCircle(
      center.translate(0, 2),
      _radius,
      Paint()
        ..color = const Color(0x382A1810)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    canvas.drawCircle(center, _radius, Paint()..color = AppColors.white);
    canvas.drawCircle(
      center,
      _radius - 1,
      Paint()
        ..color = AppColors.espresso
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(center, 3, Paint()..color = AppColors.espresso);
  }
}

/// "Which Thursdays?" — asked when saving or clearing a day a weekly repeat
/// covers. Resolves to the scope, or null when dismissed (back to the
/// plan, edits kept).
class _RepeatScopeSheet extends StatelessWidget {
  final DateTime date;
  final bool clearing;
  const _RepeatScopeSheet({required this.date, required this.clearing});

  static Future<DayPlanScope?> ask(
    BuildContext context,
    DateTime date, {
    required bool clearing,
  }) {
    return AppBottomSheet.show<DayPlanScope>(
      context,
      builder: (_) => _RepeatScopeSheet(date: date, clearing: clearing),
    );
  }

  @override
  Widget build(BuildContext context) {
    final weekday = weekdayLong(date);
    final day = '${monthShort(date)} ${date.day}';
    return AppBottomSheet(
      title: 'Which ${weekday}s?',
      heightFactor: 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ScopeOption(
            title: 'Just this $weekday',
            body: clearing
                ? '$day only. Your repeat carries on next week.'
                : '$day only. Your repeat stays as it is.',
            onTap: () => Navigator.of(context).pop(DayPlanScope.day),
          ),
          const SizedBox(height: 10),
          _ScopeOption(
            title: clearing ? 'Stop repeating' : 'Every $weekday from now on',
            body: 'From $day on. Past ${weekday}s stay as they were.',
            onTap: () => Navigator.of(context).pop(DayPlanScope.fromNow),
          ),
        ],
      ),
    );
  }
}

class _ScopeOption extends StatelessWidget {
  final String title;
  final String body;
  final VoidCallback onTap;
  const _ScopeOption({
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.titleSmall?.copyWith(color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(body, style: text.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}
