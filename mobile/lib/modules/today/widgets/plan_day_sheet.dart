import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../onboarding/widgets/pipeda_note.dart';
import '../day_plans_controller.dart';
import '../models/day_plan.dart';
import 'outfit_card.dart';

/// What the sheet hands back: a plan to save, or "clear this day".
sealed class _PlanResult {
  const _PlanResult();
}

class _Saved extends _PlanResult {
  final DayPlan plan;
  const _Saved(this.plan);
}

class _Cleared extends _PlanResult {
  const _Cleared();
}

/// Plan the day (Stitch `plan_the_day_thursday_nov_5`): what's on (one of 12
/// occasions), how dressed up (5 stops, defaulted by the occasion), a note,
/// repeat-weekly, then Save. UI-only — saves go to [dayPlansProvider].
class PlanDaySheet extends StatefulWidget {
  final DateTime date;
  final DayPlan? existing;

  /// e.g. "6°C · Rain" — only known for today until the frame carries a
  /// forecast; hidden when null.
  final String? weatherLabel;
  final IconData? weatherIcon;

  const PlanDaySheet({
    super.key,
    required this.date,
    this.existing,
    this.weatherLabel,
    this.weatherIcon,
  });

  /// Opens the sheet for [date], applies the result, and confirms with an
  /// undoable toast ("Planned: Work day, Thursday…").
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
    final result = await showModalBottomSheet<_PlanResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.espressoDeep.withValues(alpha: 0.55),
      builder: (_) => PlanDaySheet(
        date: date,
        existing: previous,
        weatherLabel: weatherLabel,
        weatherIcon: weatherIcon,
      ),
    );
    if (result == null) return;

    final String message;
    switch (result) {
      case _Saved(:final plan):
        controller.save(plan);
        message = _plannedMessage(plan);
      case _Cleared():
        controller.clear(date);
        message = 'Plan cleared for ${_dayName(date)}.';
    }
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
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.white,
            onPressed: () => controller.restore(date, previous),
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
    _repeat = e?.repeatWeekly ?? false;
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

  void _save() {
    final o = _occasion;
    if (o == null) return;
    Navigator.of(context).pop(
      _Saved(
        DayPlan(
          date: widget.date,
          occasion: o,
          dress: _dress,
          note: _note.text.trim(),
          repeatWeekly: _repeat,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = widget.date;
    final weekday = weekdayLong(date);
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        height: media.size.height * 0.8,
        decoration: const BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Grabber hugs the top edge. No close button: the sheet is
            // dismissed by dragging it down or tapping outside it.
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 20),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.taupeSoft.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                // Not a lazy ListView: every section must be built so
                // answering can scroll the next one into view.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
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
                              style: text.titleSmall?.copyWith(
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            '${_note.text.length} / $_noteMax',
                            style: text.bodySmall?.copyWith(
                              color: AppColors.taupe,
                            ),
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
                            onPressed: () =>
                                Navigator.of(context).pop(const _Cleared()),
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
                ),
              ),
            ),
            _footer(text),
          ],
        ),
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

  Widget _footer(TextTheme text) {
    final enabled = _occasion != null;
    return Container(
      color: AppColors.ivory.withValues(alpha: 0.95),
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
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
      ),
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
