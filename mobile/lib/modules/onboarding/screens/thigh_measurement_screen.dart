import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
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
    context.pushNamed(ShouldersScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementStepScaffold(
      step: 7,
      stepLabel: 'THIGH',
      bodyPart: 'thigh',
      title: 'Thigh',
      description:
          'Tape around the fullest part of one thigh, just below where it meets your hip.',
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
