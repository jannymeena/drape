import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../models/measurements_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/measurement_input.dart';
import '../widgets/measurement_step_scaffold.dart';
import 'wardrobe_setup_screen.dart';

/// Final measurement screen (step 8). "Keep Going" stores the shoulders value and
/// then submits the whole set in one `POST /profile/measurements`; on success
/// the flow moves on to wardrobe setup.
class ShouldersScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/measurements/shoulders';
  static const name = 'shoulders';

  const ShouldersScreen({super.key});

  @override
  ConsumerState<ShouldersScreen> createState() => _ShouldersScreenState();
}

class _ShouldersScreenState extends ConsumerState<ShouldersScreen> {
  double? _cm;
  bool _imperial = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _cm = ref.read(onboardingControllerProvider).measurements.get(MeasurementField.shoulders);
  }

  Future<void> _onSubmit() async {
    if (_cm == null || _submitting) return;
    final notifier = ref.read(onboardingControllerProvider.notifier);
    notifier.setMeasurement(MeasurementField.shoulders, _cm, imperial: _imperial);

    setState(() => _submitting = true);
    try {
      await notifier.submitMeasurements();
      if (!mounted) return;
      context.pushNamed(WardrobeSetupScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MeasurementStepScaffold(
      step: 8,
      stepLabel: 'SHOULDERS',
      bodyPart: 'shoulders',
      title: 'Shoulders',
      description:
          'Measure from the edge of one shoulder to the other across your back.',
      canContinue: _cm != null,
      loading: _submitting,
      onContinue: _onSubmit,
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
