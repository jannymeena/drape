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
  bool _imperial = true;

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
    return Scaffold(
      appBar: const DrapeAppBar(
        title: 'Build Your Avatar',
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.lock_outline, color: AppColors.inkSoft),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const _StepDots(currentStep: 3, totalSteps: 8, label: 'Chest / Bust'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  const MeasurementGuide(bodyPart: 'chest'),
                  const SizedBox(height: 24),
                  Text(
                    'Chest / Bust',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tape around the fullest part of your chest. Breathe normally.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 28),
                  MeasurementInput(
                    metricLabel: 'cm',
                    imperialLabel: 'in',
                    initialUnit: _cm != null
                        ? MeasurementUnit.metric
                        : MeasurementUnit.imperial,
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

class _StepDots extends StatelessWidget {
  final int currentStep;
  final int totalSteps;
  final String label;
  const _StepDots({
    required this.currentStep,
    required this.totalSteps,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(totalSteps * 2 - 1, (i) {
              if (i.isOdd) {
                return Expanded(
                  child: Container(
                    height: 1,
                    color: AppColors.taupeSoft,
                  ),
                );
              }
              final stepNum = (i ~/ 2) + 1;
              final isDone = stepNum < currentStep;
              final isCurrent = stepNum == currentStep;
              return Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.espresso
                      : (isCurrent ? AppColors.white : AppColors.tanFixed),
                  border: Border.all(
                    color: isCurrent ? AppColors.espresso : AppColors.tanFixed,
                    width: isCurrent ? 2 : 0,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: isDone
                    ? const Icon(Icons.check, color: AppColors.white, size: 14)
                    : null,
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
