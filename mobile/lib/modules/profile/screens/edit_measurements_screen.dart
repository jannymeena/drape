import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../onboarding/models/measurements_draft.dart';
import '../profile_service.dart';

/// Edit the user's body measurements from the Profile tab. Loads the current
/// values via `GET /profile/measurements` (decrypted server-side) and saves the
/// full set back via `POST /profile/measurements` (the same bulk-upsert endpoint
/// onboarding uses — the backend re-encrypts at rest).
///
/// Values are held canonically in metric; the unit toggle only changes display
/// and is converted on save. Weight is optional; the other seven are required.
class EditMeasurementsScreen extends ConsumerStatefulWidget {
  static const path = 'measurements';
  static const name = 'profile_measurements';

  const EditMeasurementsScreen({super.key});

  @override
  ConsumerState<EditMeasurementsScreen> createState() =>
      _EditMeasurementsScreenState();
}

class _EditMeasurementsScreenState
    extends ConsumerState<EditMeasurementsScreen> {
  // (field, label, isWeight). Weight is the only optional field and the only one
  // that uses the lbs↔kg factor.
  static const _fields = <(MeasurementField, String, bool)>[
    (MeasurementField.height, 'Height', false),
    (MeasurementField.weight, 'Weight', true),
    (MeasurementField.shoulders, 'Shoulders', false),
    (MeasurementField.chest, 'Chest', false),
    (MeasurementField.waist, 'Waist', false),
    (MeasurementField.inseam, 'Inseam', false),
    (MeasurementField.thigh, 'Thigh', false),
    (MeasurementField.hips, 'Hips', false),
  ];

  static const _lengthFactor = 2.54; // in → cm
  static const _weightFactor = 0.45359237; // lbs → kg

  final _controllers = {
    for (final f in _fields) f.$1: TextEditingController(),
  };

  bool _imperial = false;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _factor(bool isWeight) => isWeight ? _weightFactor : _lengthFactor;

  String _unitSuffix(bool isWeight) => isWeight
      ? (_imperial ? 'lbs' : 'kg')
      : (_imperial ? 'in' : 'cm');

  void _seedOnce(MeasurementsDraft? draft) {
    if (_seeded) return;
    _seeded = true;
    if (draft == null) return;
    _imperial = draft.unitSystem == 'imperial';
    for (final (field, _, isWeight) in _fields) {
      final metric = draft.get(field);
      if (metric == null) continue;
      final shown = _imperial ? metric / _factor(isWeight) : metric;
      _controllers[field]!.text = formatMeasurement(shown);
    }
  }

  void _toggleUnit(bool imperial) {
    if (imperial == _imperial) return;
    setState(() {
      for (final (field, _, isWeight) in _fields) {
        final controller = _controllers[field]!;
        final parsed = double.tryParse(controller.text.trim());
        if (parsed == null || parsed <= 0) continue;
        final metric = _imperial ? parsed * _factor(isWeight) : parsed;
        final shown = imperial ? metric / _factor(isWeight) : metric;
        controller.text = formatMeasurement(shown);
      }
      _imperial = imperial;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final values = <MeasurementField, double>{};
    for (final (field, _, isWeight) in _fields) {
      final parsed = double.tryParse(_controllers[field]!.text.trim());
      if (parsed == null || parsed <= 0) continue;
      values[field] = _imperial ? parsed * _factor(isWeight) : parsed;
    }
    final draft = MeasurementsDraft(
      values: values,
      unitSystem: _imperial ? 'imperial' : 'metric',
    );
    if (!draft.hasAllRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in every measurement (weight is optional).'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileServiceProvider).updateMeasurements(draft);
      // Refresh any live watcher (e.g. the Today resume banner) right away.
      ref.invalidate(measurementsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Measurements saved.')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't save — check your connection."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(measurementsProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop(), onSave: _saving ? null : _save),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your measurements.",
                  onRetry: () => ref.invalidate(measurementsProvider),
                ),
                data: (draft) {
                  _seedOnce(draft);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      Text(
                        'Used to personalize fit. Stored encrypted — only you can see these.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      _UnitToggle(
                        imperial: _imperial,
                        onChanged: _toggleUnit,
                      ),
                      const SizedBox(height: 20),
                      for (final (field, label, isWeight) in _fields) ...[
                        _MeasureRow(
                          label: isWeight ? '$label (optional)' : label,
                          controller: _controllers[field]!,
                          unit: _unitSuffix(isWeight),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback? onSave;
  const _Header({required this.onBack, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Body Measurements',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          TextButton(
            onPressed: onSave,
            child: Text(
              'Save',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final bool imperial;
  final ValueChanged<bool> onChanged;
  const _UnitToggle({required this.imperial, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Expanded(child: _pill(context, 'METRIC', !imperial, () => onChanged(false))),
          Expanded(child: _pill(context, 'IMPERIAL', imperial, () => onChanged(true))),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? AppColors.white : AppColors.inkSoft,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
        ),
      ),
    );
  }
}

class _MeasureRow extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String unit;
  const _MeasureRow({
    required this.label,
    required this.controller,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleSmall),
          ),
          SizedBox(
            width: 90,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.right,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: Theme.of(context).textTheme.titleMedium,
              decoration: const InputDecoration(
                hintText: '0.0',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 32,
            child: Text(
              unit,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.taupe),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
