import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../models/day_plan.dart';
import 'outfit_card.dart';

enum WeekDayStatus {
  /// Today — always styled, drawn as the filled espresso marker.
  today,

  /// A plan exists for the day; [WeekDayCell.icon] names it.
  planned,

  /// Nothing planned yet — dashed "+" marker.
  open,
}

class WeekDayCell {
  final DateTime date;
  final WeekDayStatus status;

  /// The plan's icon (e.g. work → briefcase); ignored for [WeekDayStatus.open].
  final IconData icon;

  const WeekDayCell({
    required this.date,
    required this.status,
    this.icon = Icons.checkroom,
  });
}

/// The summary row under the strip about tomorrow's plan.
class TomorrowSummary {
  final String title;
  final String subtitle;
  final String actionLabel;
  final bool planned;

  const TomorrowSummary({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.planned,
  });
}

/// "Your next 7 days": header with PLAN WEEK, the 7-day ribbon (filled =
/// planned, dashed = needs a plan) and the tomorrow summary card.
class WeekPlanStrip extends StatelessWidget {
  final List<WeekDayCell> days;
  final TomorrowSummary? tomorrow;
  final VoidCallback onPlanWeek;
  final ValueChanged<DateTime> onDayTap;
  final VoidCallback? onTomorrowAction;

  const WeekPlanStrip({
    super.key,
    required this.days,
    required this.onPlanWeek,
    required this.onDayTap,
    this.tomorrow,
    this.onTomorrowAction,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Your next 7 days',
                // Newsreader, like the greeting and the other Today titles;
                // lining figures so the 7 doesn't sit low.
                style: AppTypography.sectionTitle.copyWith(
                  fontFeatures: const [FontFeature.liningFigures()],
                ),
              ),
            ),
            TextButton(
              onPressed: onPlanWeek,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.espressoDark,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                minimumSize: const Size(48, 40),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PLAN WEEK',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.espressoDark,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: todayCardShadow,
          ),
          child: Row(
            children: [
              for (final (i, d) in days.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                Expanded(child: _DayCell(day: d, onTap: () => onDayTap(d.date))),
              ],
            ],
          ),
        ),
        if (tomorrow != null) ...[
          const SizedBox(height: 12),
          _TomorrowCard(summary: tomorrow!, onAction: onTomorrowAction),
        ],
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final WeekDayCell day;
  final VoidCallback onTap;
  const _DayCell({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final isToday = day.status == WeekDayStatus.today;
    return Semantics(
      button: true,
      label: '${weekdayShort(day.date)} ${day.date.day}, '
          '${day.status == WeekDayStatus.open ? 'needs a plan' : 'planned'}',
      excludeSemantics: true,
      child: Material(
        color: isToday ? AppColors.ivoryWarm : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  weekdayShort(day.date).toUpperCase(),
                  style: text.labelSmall?.copyWith(
                    fontSize: 10,
                    letterSpacing: 0.4,
                    color: isToday ? AppColors.espressoDark : AppColors.taupe,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                Text(
                  '${day.date.day}',
                  style: text.headlineSmall?.copyWith(
                    fontSize: 20,
                    height: 1.2,
                    // Cormorant defaults to old-style figures ("10" reads
                    // as "IO").
                    fontFeatures: const [FontFeature.liningFigures()],
                    color: isToday ? AppColors.espressoDark : AppColors.ink,
                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                _DayMarker(day: day),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayMarker extends StatelessWidget {
  final WeekDayCell day;
  const _DayMarker({required this.day});

  @override
  Widget build(BuildContext context) {
    switch (day.status) {
      case WeekDayStatus.today:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.espressoDark,
            shape: BoxShape.circle,
          ),
          child: Icon(day.icon, size: 13, color: AppColors.white),
        );
      case WeekDayStatus.planned:
        return Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: AppColors.ivoryWarm,
            shape: BoxShape.circle,
          ),
          child: Icon(day.icon, size: 13, color: AppColors.espressoDark),
        );
      case WeekDayStatus.open:
        return CustomPaint(
          painter: const _DashedCirclePainter(color: AppColors.taupe),
          child: const SizedBox(
            width: 24,
            height: 24,
            child: Icon(Icons.add, size: 13, color: AppColors.taupe),
          ),
        );
    }
  }
}

class _DashedCirclePainter extends CustomPainter {
  final Color color;
  const _DashedCirclePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2 - 0.5;
    final center = size.center(Offset.zero);
    canvas.drawCircle(center, radius, Paint()..color = AppColors.ivoryDim);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    const dashes = 12;
    const sweep = 2 * math.pi / dashes;
    final rect = Rect.fromCircle(center: center, radius: radius);
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter old) => old.color != color;
}

class _TomorrowCard extends StatelessWidget {
  final TomorrowSummary summary;
  final VoidCallback? onAction;
  const _TomorrowCard({required this.summary, this.onAction});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: todayCardShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: summary.planned ? AppColors.sage : AppColors.taupeSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        summary.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(color: AppColors.ink),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  summary.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: AppColors.taupe),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Material(
            color: AppColors.ivoryWarm,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  summary.actionLabel,
                  style: text.labelMedium?.copyWith(color: AppColors.espressoDark),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
