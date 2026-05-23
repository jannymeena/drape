/// The body measurements collected one-per-screen during onboarding, held in
/// the controller until the single bulk `POST /profile/measurements`.
///
/// Values are stored canonically in **metric** (cm for lengths, kg for weight) —
/// screens convert imperial input before storing. `weight` is optional; the
/// other seven are required by the backend, so [hasAllRequired] gates the submit.
library;

enum MeasurementField { height, weight, shoulders, chest, waist, inseam, thigh, hips }

/// The seven measurements the backend requires (everything except weight).
const _required = [
  MeasurementField.height,
  MeasurementField.shoulders,
  MeasurementField.chest,
  MeasurementField.waist,
  MeasurementField.inseam,
  MeasurementField.thigh,
  MeasurementField.hips,
];

/// Trims a trailing `.0` so prefilled fields read "175" rather than "175.0".
String formatMeasurement(double v) {
  final s = v.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

class MeasurementsDraft {
  const MeasurementsDraft({
    this.values = const {},
    this.unitSystem = 'metric',
  });

  /// Only entered fields are present; all values are metric (cm / kg).
  final Map<MeasurementField, double> values;

  /// Display hint echoed to the backend ('metric' | 'imperial') — the last unit
  /// the user toggled. Stored values are always metric regardless.
  final String unitSystem;

  double? get(MeasurementField field) => values[field];

  /// Returns a copy with [field] set to [metric] (or removed when null).
  MeasurementsDraft setField(
    MeasurementField field,
    double? metric, {
    String? unitSystem,
  }) {
    final next = Map<MeasurementField, double>.from(values);
    if (metric == null) {
      next.remove(field);
    } else {
      next[field] = metric;
    }
    return MeasurementsDraft(
      values: next,
      unitSystem: unitSystem ?? this.unitSystem,
    );
  }

  bool get hasAllRequired => _required.every(values.containsKey);

  /// Wire shape for `MeasurementsRequest`. weight_kg may be null (optional).
  Map<String, dynamic> toJson() => {
        'height_cm': values[MeasurementField.height],
        'weight_kg': values[MeasurementField.weight],
        'shoulders_cm': values[MeasurementField.shoulders],
        'chest_cm': values[MeasurementField.chest],
        'waist_cm': values[MeasurementField.waist],
        'inseam_cm': values[MeasurementField.inseam],
        'thigh_cm': values[MeasurementField.thigh],
        'hips_cm': values[MeasurementField.hips],
        'unit_system': unitSystem,
      };
}
