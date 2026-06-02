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
import 'weight_input_screen.dart';

class HeightInputScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/height';
  static const name = 'height';

  const HeightInputScreen({super.key});

  @override
  ConsumerState<HeightInputScreen> createState() => _HeightInputScreenState();
}

class _HeightInputScreenState extends ConsumerState<HeightInputScreen> {
  double? _cm;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.height);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.height, _cm, imperial: _imperial);
    context.pushNamed(WeightInputScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(
        title: 'Your DRAPE Profile — Step 1 of 8',
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(step: 1, totalSteps: 8),
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
                      child: const Icon(Icons.height,
                          color: AppColors.espresso, size: 28),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Height',
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stand against a wall. Measure from floor to top of head.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  MeasurementInput(
                    metricLabel: 'cm',
                    imperialLabel: 'in',
                    hint: 'e.g., 175 cm or 69 in',
                    initialValue: _cm != null ? formatMeasurement(_cm!) : null,
                    onReading: (metric, unit) => setState(() {
                      _cm = metric;
                      _imperial = unit == MeasurementUnit.imperial;
                    }),
                  ),
                  const SizedBox(height: 20),
                  _PrivacyBanner(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: DrapeButton(
                label: 'Continue',
                onPressed: _cm == null ? null : _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, color: AppColors.sage, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Your measurements stay on your device and in your encrypted profile. Never shared.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Icon(Icons.info_outline, color: AppColors.inkSoft, size: 16),
        ],
      ),
    );
  }
}
