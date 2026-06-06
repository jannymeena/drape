import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
import 'hips_measurement_screen.dart';

class WaistMeasurementScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/waist';
  static const name = 'waist';

  const WaistMeasurementScreen({super.key});

  @override
  ConsumerState<WaistMeasurementScreen> createState() =>
      _WaistMeasurementScreenState();
}

class _WaistMeasurementScreenState extends ConsumerState<WaistMeasurementScreen> {
  double? _cm;
  bool _imperial = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.waist);
  }

  void _onContinue() {
    if (_cm == null) return;
    ref
        .read(onboardingControllerProvider.notifier)
        .setMeasurement(MeasurementField.waist, _cm, imperial: _imperial);
    context.pushNamed(HipsMeasurementScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementStepScaffold(
      step: 4,
      stepLabel: 'WAIST',
      bodyPart: 'waist',
      title: 'Waist',
      description:
          'Measure at the narrowest part of your torso, usually just above the belly button.',
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
