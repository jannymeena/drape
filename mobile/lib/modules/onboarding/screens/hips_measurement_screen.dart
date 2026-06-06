import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
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
    return MeasurementStepScaffold(
      step: 5,
      stepLabel: 'HIPS',
      bodyPart: 'hips',
      title: 'Hips',
      description:
          'Tape around the fullest part of your hips, keeping the tape level all the way around.',
      canContinue: _cm != null,
      onContinue: _onContinue,
      input: MeasurementInput(
        metricLabel: 'cm',
        imperialLabel: 'in',
        initialValue: _cm != null ? formatMeasurement(_cm!) : null,
        onReading: (metric, unit) => setState(() {
          _cm = metric;
          _imperial = unit == MeasurementUnit.imperial;
        }),
      ),
    );
  }
}
