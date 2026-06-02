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
import 'inseam_measurement_screen.dart';

class HipsMeasurementScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/hips';
  static const name = 'hips';

  const HipsMeasurementScreen({super.key});

  @override
  ConsumerState<HipsMeasurementScreen> createState() =>
      _HipsMeasurementScreenState();
}

class _HipsMeasurementScreenState extends ConsumerState<HipsMeasurementScreen> {
  double? _cm;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.hips);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.hips, _cm, imperial: _imperial);
    context.pushNamed(InseamMeasurementScreen.name);
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
                'STEP 5 OF 8 — HIPS',
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
                  const MeasurementGuide(bodyPart: 'hips'),
                  const SizedBox(height: 24),
                  Text('Hips',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Tape around the fullest part of your hips, keeping the tape level all the way around.',
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
