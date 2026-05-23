import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

enum MeasurementUnit { metric, imperial }

class MeasurementInput extends StatefulWidget {
  final String metricLabel;
  final String imperialLabel;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final MeasurementUnit initialUnit;

  /// Imperial→metric multiplier applied when the imperial unit is selected:
  /// 2.54 for length (in→cm), 0.45359237 for weight (lbs→kg).
  final double imperialFactor;

  /// Reports the entered value already converted to metric (null when the field
  /// is empty or unparseable), plus the unit currently selected. Fires on every
  /// keystroke and unit toggle.
  final void Function(double? metric, MeasurementUnit unit)? onReading;

  /// Optional text to prefill (used to restore a value on back-navigation).
  final String? initialValue;

  const MeasurementInput({
    super.key,
    this.metricLabel = 'cm',
    this.imperialLabel = 'in',
    this.hint,
    this.onChanged,
    this.initialUnit = MeasurementUnit.metric,
    this.imperialFactor = 2.54,
    this.onReading,
    this.initialValue,
  });

  @override
  State<MeasurementInput> createState() => _MeasurementInputState();
}

class _MeasurementInputState extends State<MeasurementInput> {
  late MeasurementUnit _unit;
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _unit = widget.initialUnit;
    if (widget.initialValue != null) _controller.text = widget.initialValue!;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Parses the field, converts to metric when imperial, and reports it.
  void _emitReading() {
    final parsed = double.tryParse(_controller.text.trim());
    double? metric;
    if (parsed != null && parsed > 0) {
      metric = _unit == MeasurementUnit.metric
          ? parsed
          : parsed * widget.imperialFactor;
    }
    widget.onReading?.call(metric, _unit);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UnitToggle(
          unit: _unit,
          metricLabel: widget.metricLabel,
          imperialLabel: widget.imperialLabel,
          onChanged: (u) {
            setState(() => _unit = u);
            _emitReading();
          },
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.white,
            border: Border.all(color: AppColors.taupeSoft),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                  decoration: InputDecoration(
                    hintText: '0.0',
                    hintStyle: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: AppColors.taupe,
                        ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    widget.onChanged?.call(v);
                    _emitReading();
                  },
                ),
              ),
              Text(
                _unit == MeasurementUnit.metric
                    ? widget.metricLabel
                    : widget.imperialLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ],
          ),
        ),
        if (widget.hint != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.hint!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.taupe,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ],
      ],
    );
  }
}

class _UnitToggle extends StatelessWidget {
  final MeasurementUnit unit;
  final String metricLabel;
  final String imperialLabel;
  final ValueChanged<MeasurementUnit> onChanged;
  const _UnitToggle({
    required this.unit,
    required this.metricLabel,
    required this.imperialLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tanFixed,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _UnitPill(
            label: 'METRIC',
            selected: unit == MeasurementUnit.metric,
            onTap: () => onChanged(MeasurementUnit.metric),
          ),
          _UnitPill(
            label: 'IMPERIAL',
            selected: unit == MeasurementUnit.imperial,
            onTap: () => onChanged(MeasurementUnit.imperial),
          ),
        ],
      ),
    );
  }
}

class _UnitPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _UnitPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
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
