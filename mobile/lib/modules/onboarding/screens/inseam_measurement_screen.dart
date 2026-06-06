import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
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
    return MeasurementStepScaffold(
      step: 6,
      stepLabel: 'INSEAM',
      bodyPart: 'inseam',
      title: 'Inseam',
      description:
          'Measure from your crotch down to the floor along the inside of your leg.',
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
