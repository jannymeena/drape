import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../day_plans_controller.dart';
import '../models/day_plan.dart';
import '../today_controller.dart';
import '../widgets/dashed_outline.dart';
import '../widgets/plan_day_sheet.dart';
import '../widgets/weather_chip.dart';

/// Plan your week (Stitch `plan_your_week_zoura`): progress, quick-start
/// presets, one row per day (tap → Plan the day), Done. UI-only — plans
/// live in [dayPlansProvider].
class PlanWeekScreen extends ConsumerWidget {
  static const path = 'plan-week';
  static const name = 'plan_week';

  const PlanWeekScreen({super.key});

  static const _gutter = 24.0;

  void _openDay(BuildContext context, WidgetRef ref, DateTime date) {
    final w = ref.read(todayControllerProvider).dashboard?.weather;
    final isToday = daysFromToday(date) == 0;
    final condition = w == null ? null : weatherConditionLabel(w.condition);
    PlanDaySheet.open(
      context,
      ref,
      date,
      weatherLabel: isToday && w != null
          ? '${w.tempC.round()}°C${condition == null ? '' : ' · $condition'}'
          : null,
      weatherIcon: w == null ? null : weatherConditionIcon(w.condition),
    );
  }

  void _preset(
    BuildContext context,
    WidgetRef ref,
    List<DateTime> days, {
    required bool Function(DateTime) when,
    required DayOccasion occasion,
  }) {
    final filled = ref
        .read(dayPlansProvider.notifier)
        .fill(days, when: when, occasion: occasion);
    showDrapeToast(
      context,
      filled == 0
          ? 'Those days already have plans.'
          : 'Planned ${filled == 1 ? '1 day' : '$filled days'} as ${occasion.label}.',
      background: AppColors.espressoDeep,
    );
  }

  static bool _isWeekday(DateTime d) => d.weekday <= DateTime.friday;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plans = ref.watch(dayPlansProvider);
    final days = nextSevenDays();
    // Today is always styled, so it counts as planned (same as the strip).
    final planned = days
        .where((d) => daysFromToday(d) == 0 || plans[d] != null)
        .length;
    final toPlan = days.length - planned;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Back + centred title.
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: const Icon(
                      Icons.chevron_left,
                      size: 28,
                      color: AppColors.espressoDark,
                    ),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Text(
                      'Plan your week',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(
                        color: AppColors.espressoDark,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 24),
                children: [
                  Text(
                    'Tell us what is coming up. We style each outfit the '
                    'evening before.',
                    style: text.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _ProgressCard(
                    planned: planned,
                    total: days.length,
                    toPlan: toPlan,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'QUICK START',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.inkSoft,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      // Bleed to the screen edges while the first chip lines
                      // up with the gutter.
                      clipBehavior: Clip.none,
                      children: [
                        _PresetChip(
                          icon: Icons.work_outline,
                          label: 'Weekdays: Work day',
                          onTap: () => _preset(
                            context,
                            ref,
                            days,
                            when: _isWeekday,
                            occasion: DayOccasion.workDay,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          icon: Icons.wb_sunny_outlined,
                          label: 'Weekend: Day off',
                          onTap: () => _preset(
                            context,
                            ref,
                            days,
                            when: (d) => !_isWeekday(d),
                            occasion: DayOccasion.dayOff,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PresetChip(
                          icon: Icons.content_copy_outlined,
                          label: 'Copy last week',
                          onTap: () => showDrapeToast(
                            context,
                            'Copy last week is coming soon.',
                            icon: Icons.schedule,
                            background: AppColors.espressoDeep,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  for (final d in days) ...[
                    _DayRow(
                      date: d,
                      plan: plans[d],
                      onTap: () => _openDay(context, ref, d),
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _DoneBar(
        onDone: () => Navigator.of(context).maybePop(),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  final int planned;
  final int total;
  final int toPlan;
  const _ProgressCard({
    required this.planned,
    required this.total,
    required this.toPlan,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.sand),
        boxShadow: _rowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$planned of $total planned',
                  style: text.titleMedium?.copyWith(
                    color: AppColors.espressoDeep,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                toPlan == 0
                    ? 'All planned'
                    : (toPlan == 1 ? '1 day to plan' : '$toPlan days to plan'),
                style: text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : planned / total,
              minHeight: 4,
              backgroundColor: AppColors.sand,
              valueColor: const AlwaysStoppedAnimation(AppColors.espresso),
            ),
          ),
        ],
      ),
    );
  }
}

const _rowShadow = [
  BoxShadow(color: Color(0x0A2A1810), blurRadius: 4, offset: Offset(0, 1)),
];

class _PresetChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _PresetChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppColors.espressoDeep),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.espressoDeep,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One day: date tile (filled = planned, dashed = needs a plan), the plan
/// chip + "Smart casual • Ready by 10 pm" (or a dashed "Add plan"), chevron.
class _DayRow extends StatelessWidget {
  final DateTime date;
  final DayPlan? plan;
  final VoidCallback onTap;
  const _DayRow({required this.date, required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isToday = daysFromToday(date) == 0;
    // Today is styled daily even without a plan.
    final filled = plan != null || isToday;
    return Semantics(
      button: true,
      label:
          '${weekdayLong(date)} ${date.day}, '
          '${plan?.title ?? (isToday ? "today's picks" : 'needs a plan')}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.sand),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _DateTile(date: date, filled: filled, isToday: isToday),
                  const SizedBox(width: 12),
                  Expanded(
                    child: filled
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PlanChip(
                                icon: plan?.occasion.icon ?? Icons.checkroom,
                                label: plan?.title ?? "Today's picks",
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  plan == null
                                      ? 'Styled for your day • Ready now'
                                      : '${plan!.dress.label} • ${readyLabel(date)}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: text.bodySmall,
                                ),
                              ),
                            ],
                          )
                        // Full width, and as tall as the date tile beside it.
                        : DashedOutline(
                            color: AppColors.taupe,
                            fill: AppColors.white,
                            child: SizedBox(
                              height: _DateTile.size,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.add,
                                    size: 18,
                                    color: AppColors.espresso,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Add plan',
                                    style: text.titleSmall?.copyWith(
                                      color: AppColors.espresso,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.inkSoft),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  /// Square tile edge; the "Add plan" button matches its height.
  static const size = 56.0;

  final DateTime date;
  final bool filled;
  final bool isToday;
  const _DateTile({
    required this.date,
    required this.filled,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fg = filled ? AppColors.white : AppColors.espressoDeep;
    final content = SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            weekdayShort(date),
            style: text.bodySmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
          Text(
            '${date.day}',
            style: text.titleLarge?.copyWith(
              color: fg,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
    final tile = filled
        ? DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF7B5238), AppColors.espressoDark],
              ),
              boxShadow: _rowShadow,
            ),
            child: content,
          )
        : DashedOutline(
            color: AppColors.taupe,
            fill: AppColors.ivoryDim,
            child: content,
          );
    if (!isToday) return tile;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        tile,
        Positioned(
          top: -6,
          right: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.ivoryWarm,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.white),
            ),
            child: Text(
              'Today',
              style: text.labelSmall?.copyWith(
                fontSize: 10,
                letterSpacing: 0,
                color: AppColors.espresso,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PlanChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlanChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.espressoDeep),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(color: AppColors.espressoDeep),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoneBar extends StatelessWidget {
  final VoidCallback onDone;
  const _DoneBar({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ivory.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(color: AppColors.sand.withValues(alpha: 0.4)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B5238), AppColors.espresso],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x266B4530),
                  blurRadius: 12,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onDone,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      'Done',
                      style: Theme.of(
                        context,
                      ).textTheme.titleMedium?.copyWith(color: AppColors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
