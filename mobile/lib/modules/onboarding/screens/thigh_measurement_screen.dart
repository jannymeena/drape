import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_guide.dart';
import '../widgets/measurement_input.dart';
import 'shoulders_screen.dart';

/// Step 7 of the 8-step measurement flow. The backend requires `thigh_cm`, but
/// no screen previously collected it (the indicator already read "of 8"); this
/// fills that gap. Sits between inseam and shoulders.
class ThighMeasurementScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/thigh';
  static const name = 'thigh';

  const ThighMeasurementScreen({super.key});

  @override
  ConsumerState<ThighMeasurementScreen> createState() =>
      _ThighMeasurementScreenState();
}

class _ThighMeasurementScreenState
    extends ConsumerState<ThighMeasurementScreen> {
  double? _cm;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.thigh);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.thigh, _cm, imperial: _imperial);
    context.goNamed(ShouldersScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Build Your Avatar'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'STEP 7 OF 8 — THIGH',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.espresso,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  const MeasurementGuide(bodyPart: 'thigh'),
                  const SizedBox(height: 24),
                  Text('Thigh',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tape around the fullest part of one thigh, just below where it meets your hip.',
                    style: Theme.of(context).textTheme.bodyMedium,
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
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: DrapeButton(
                label: 'Keep Going',
                onPressed: _cm == null ? null : _onContinue,
                leading: const Icon(Icons.arrow_forward,
                    color: AppColors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
