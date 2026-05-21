import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/measurement_guide.dart';
import '../widgets/measurement_input.dart';
import 'waist_measurement_screen.dart';

class ChestMeasurementScreen extends StatelessWidget {
  static const path = '/onboarding/measurements/chest';
  static const name = 'chest';

  const ChestMeasurementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(
        title: 'Build Your Avatar',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.lock_outline, color: AppColors.inkSoft),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _StepDots(currentStep: 3, totalSteps: 8, label: 'Chest / Bust'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  const MeasurementGuide(bodyPart: 'chest'),
                  const SizedBox(height: 24),
                  Text(
                    'Chest / Bust',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tape around the fullest part of your chest. Breathe normally.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  const MeasurementInput(
                    metricLabel: 'cm',
                    imperialLabel: 'in',
                    initialUnit: MeasurementUnit.imperial,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                children: [
                  DrapeButton(
                    label: 'Keep Going',
                    onPressed: () => context.goNamed(WaistMeasurementScreen.name),
                    leading: const Icon(Icons.arrow_forward,
                        color: AppColors.white, size: 18),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context.goNamed(WaistMeasurementScreen.name),
                    child: Text(
                      'Skip chest for now',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.inkSoft,
                            decoration: TextDecoration.underline,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String label;
  const _StepDots({
    required this.currentStep,
    required this.totalSteps,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                return Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.taupeSoft,
                  ),
                );
              }
              final stepNum = (i ~/ 2) + 1;
              final isDone = stepNum < currentStep;
              final isCurrent = stepNum == currentStep;
              return Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.espresso
                      : (isCurrent ? AppColors.white : AppColors.tanFixed),
                  border: Border.all(
                    color: isCurrent ? AppColors.espresso : AppColors.tanFixed,
                    width: isCurrent ? 2 : 0,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, color: AppColors.white, size: 14)
                    : null,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
