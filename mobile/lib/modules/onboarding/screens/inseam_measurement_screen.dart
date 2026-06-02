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
import 'thigh_measurement_screen.dart';

class InseamMeasurementScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/inseam';
  static const name = 'inseam';

  const InseamMeasurementScreen({super.key});

  @override
  ConsumerState<InseamMeasurementScreen> createState() =>
      _InseamMeasurementScreenState();
}

class _InseamMeasurementScreenState
    extends ConsumerState<InseamMeasurementScreen> {
  double? _cm;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.inseam);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.inseam, _cm, imperial: _imperial);
    context.pushNamed(ThighMeasurementScreen.name);
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
                'STEP 6 OF 8 — INSEAM',
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
                  const MeasurementGuide(bodyPart: 'inseam'),
                  const SizedBox(height: 24),
                  Text('Inseam',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Measure from your crotch down to the floor along the inside of your leg.',
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
