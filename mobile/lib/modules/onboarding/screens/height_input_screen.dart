import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
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
    return MeasurementStepScaffold(
      step: 1,
      stepLabel: 'HEIGHT',
      bodyPart: 'height',
      title: 'Height',
      description:
          'Stand against a wall. Measure from the floor to the top of your head.',
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
