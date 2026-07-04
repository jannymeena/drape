import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// "Complete your DRAPE profile" nudge — shown on the Today dashboard while
/// measurements are incomplete. Mirrors
/// `screens/CTO_Handoff_Today_Tab/today_dashboard_with_resume_banner`.
/// The whole banner is tappable and routes to the measurements editor.
class ResumeBanner extends StatelessWidget {
  static const _background = Color(0xFFFFF8EC); // warm cream (usage soft)
  static const _accent = Color(0xFFC8901C); // warm gold accent

  final int stepsDone;
  final int totalSteps;
  final VoidCallback onTap;

  const ResumeBanner({
    super.key,
    required this.stepsDone,
    this.totalSteps = 8,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: _background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldSoft),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child:
                    const Icon(Icons.track_changes, color: _accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Complete your DRAPE profile',
                      style: textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Unlock body-aware outfit suggestions',
                      style: textTheme.bodySmall
                          ?.copyWith(color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: totalSteps == 0 ? 0 : stepsDone / totalSteps,
                        minHeight: 6,
                        backgroundColor: AppColors.sand,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_accent),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$stepsDone of $totalSteps steps done',
                      style: textTheme.labelSmall?.copyWith(color: _accent),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: _accent),
            ],
          ),
        ),
      ),
    );
  }
}
