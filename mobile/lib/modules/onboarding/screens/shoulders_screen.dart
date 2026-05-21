import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/measurement_input.dart';
import '../widgets/onboarding_progress_bar.dart';
import 'avatar_reveal_screen.dart';

class ShouldersScreen extends StatelessWidget {
  static const path = '/onboarding/measurements/shoulders';
  static const name = 'shoulders';

  const ShouldersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DrapeAppBar(
        title: 'Your DRAPE Profile — Step 7 of 8',
        actions: [
          TextButton(
            onPressed: () => context.goNamed(AvatarRevealScreen.name),
            child: Text(
              'Skip for\nNow',
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.espresso,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(step: 7, totalSteps: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 220,
                      color: AppColors.ivoryWarm,
                      child: Stack(
                        children: [
                          const Center(
                            child: Icon(Icons.accessibility,
                                size: 100, color: AppColors.taupe),
                          ),
                          Positioned(
                            left: 16,
                            bottom: 16,
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.white,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.straighten,
                                  color: AppColors.espresso, size: 22),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'STEP 03',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.inkSoft,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Shoulders',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Measure from the edge of one shoulder to the other across your back.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  const MeasurementInput(metricLabel: 'CM', imperialLabel: 'in'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_outlined,
                            color: AppColors.sage, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: Theme.of(context).textTheme.bodySmall,
                              children: const [
                                TextSpan(
                                  text: 'WEEK 3 ENCRYPTION\n',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.espresso,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Your profile lives only on your device. Not even DRAPE can access it without permission.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: DrapeButton(
                label: 'CONTINUE',
                onPressed: () => context.goNamed(AvatarRevealScreen.name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
