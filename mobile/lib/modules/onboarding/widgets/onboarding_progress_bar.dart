import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Linear progress + "STEP X OF Y" centered counter.
/// Sits below DrapeAppBar; the appbar carries the title + back + skip.
class OnboardingProgressBar extends StatelessWidget {
  final int step;
  final int totalSteps;

  const OnboardingProgressBar({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    final progress = step / totalSteps;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: AppColors.tanFixed,
              valueColor: const AlwaysStoppedAnimation(AppColors.espresso),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'STEP $step OF $totalSteps',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.inkSoft,
                  letterSpacing: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
