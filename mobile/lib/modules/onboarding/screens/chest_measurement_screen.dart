import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
import 'waist_measurement_screen.dart';

class ChestMeasurementScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/chest';
  static const name = 'chest';

  const ChestMeasurementScreen({super.key});

  @override
  ConsumerState<ChestMeasurementScreen> createState() =>
      _ChestMeasurementScreenState();
}

class _ChestMeasurementScreenState extends ConsumerState<ChestMeasurementScreen> {
  double? _cm;
  // Metric default, consistent with every other measurement step.
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.chest);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.chest, _cm, imperial: _imperial);
    context.pushNamed(WaistMeasurementScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementStepScaffold(
      step: 3,
      stepLabel: 'CHEST',
      bodyPart: 'chest',
      title: 'Chest / Bust',
      description: 'Tape around the fullest part of your chest. Breathe normally.',
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
