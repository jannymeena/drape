import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../onboarding_flow.dart';
import '../widgets/measurement_input.dart';
import '../widgets/onboarding_progress_bar.dart';
import 'wardrobe_setup_screen.dart';

/// Final measurement screen (step 8). "Continue" stores the shoulders value and
/// then submits the whole set in one `POST /profile/measurements`; on success
/// the flow moves on to wardrobe setup.
class ShouldersScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/shoulders';
  static const name = 'shoulders';

  const ShouldersScreen({super.key});

  @override
  ConsumerState<ShouldersScreen> createState() => _ShouldersScreenState();
}

class _ShouldersScreenState extends ConsumerState<ShouldersScreen> {
  double? _cm;
  bool _imperial = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.shoulders);
  }

  Future<void> _onSubmit() async {
    if (_cm == null || _submitting) return;
    final notifier = ref.read(onboardingControllerProvider.notifier);
    notifier.setMeasurement(MeasurementField.shoulders, _cm, imperial: _imperial);

    setState(() => _submitting = true);
    try {
      await notifier.submitMeasurements();
      if (!mounted) return;
      context.goNamed(WardrobeSetupScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DrapeAppBar(
        title: 'Your DRAPE Profile — Step 8 of 8',
        actions: [
          TextButton(
            onPressed: () =>
                confirmSkipMeasurements(context, ref, step: 'measurements_step_8'),
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
            const OnboardingProgressBar(step: 8, totalSteps: 8),
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
                  MeasurementInput(
                    metricLabel: 'cm',
                    imperialLabel: 'in',
                    initialValue: _cm != null ? formatMeasurement(_cm!) : null,
                    onReading: (metric, unit) => setState(() {
                      _cm = metric;
                      _imperial = unit == MeasurementUnit.imperial;
                    }),
                  ),
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
                                  text: 'ENCRYPTED PROFILE\n',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.espresso,
                                    letterSpacing: 1.2,
                                  ),
                                ),
                                TextSpan(
                                  text: 'Your measurements are encrypted before they ever leave your device.',
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
                label: 'Continue',
                loading: _submitting,
                onPressed: _cm == null ? null : _onSubmit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
