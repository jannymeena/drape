import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
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
    return MeasurementStepScaffold(
      step: 2,
      stepLabel: 'WEIGHT',
      bodyPart: 'weight',
      title: 'Weight',
      description:
          'Optional. Helps with fit recommendations but not required.',
      // Optional measurement → the button stays enabled even when empty.
      canContinue: true,
      onContinue: _onContinue,
      input: MeasurementInput(
        metricLabel: 'kg',
        imperialLabel: 'lbs',
        imperialFactor: 0.45359237,
        initialValue: _kg != null ? formatMeasurement(_kg!) : null,
        onReading: (metric, unit) => setState(() {
          _kg = metric;
          _imperial = unit == MeasurementUnit.imperial;
        }),
      ),
    );
  }
}
