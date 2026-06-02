import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/onboarding_progress_bar.dart';
import 'chest_measurement_screen.dart';

/// Weight is the one optional measurement, so Continue is always enabled — a
/// blank field simply stores no weight (the bulk POST sends `weight_kg: null`).
class WeightInputScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/weight';
  static const name = 'weight';

  const WeightInputScreen({super.key});

  @override
  ConsumerState<WeightInputScreen> createState() => _WeightInputScreenState();
}

class _WeightInputScreenState extends ConsumerState<WeightInputScreen> {
  double? _kg;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _kg = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.weight);
  }

  void _onContinue() {
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.weight, _kg, imperial: _imperial);
    context.pushNamed(ChestMeasurementScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(
        title: 'Your DRAPE Profile — Step 2 of 8',
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(step: 2, totalSteps: 8),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: AppColors.ivoryWarm,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.monitor_weight_outlined,
                          color: AppColors.espresso, size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Weight',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Optional. Helps with fit recommendations but not required.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  MeasurementInput(
                    metricLabel: 'kg',
                    imperialLabel: 'lbs',
                    hint: 'e.g., 70 kg or 154 lbs',
                    imperialFactor: 0.45359237,
                    initialValue: _kg != null ? formatMeasurement(_kg!) : null,
                    onReading: (metric, unit) => setState(() {
                      _kg = metric;
                      _imperial = unit == MeasurementUnit.imperial;
                    }),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: DrapeButton(
                label: 'Continue',
                onPressed: _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
