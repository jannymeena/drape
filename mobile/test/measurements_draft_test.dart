import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/measurements_draft.dart';

/// Pure-logic coverage for the measurement accumulator: storing/clearing
/// fields, the required-set gate that protects the bulk submit, and the wire
/// shape (weight optional, all metric).
void main() {
  test('setField stores and get reads back; null clears (weight optional)', () {
    var d = const MeasurementsDraft();
    expect(d.get(MeasurementField.height), isNull);

    d = d.setField(MeasurementField.height, 175);
    expect(d.get(MeasurementField.height), 175);

    d = d.setField(MeasurementField.weight, 70);
    expect(d.get(MeasurementField.weight), 70);
    d = d.setField(MeasurementField.weight, null);
    expect(d.get(MeasurementField.weight), isNull);
  });

  test('hasAllRequired is false until all 7 required fields are present', () {
    var d = const MeasurementsDraft();
    const required = [
      MeasurementField.height,
      MeasurementField.shoulders,
      MeasurementField.chest,
      MeasurementField.waist,
      MeasurementField.inseam,
      MeasurementField.thigh,
      MeasurementField.hips,
    ];
    for (final f in required) {
      expect(d.hasAllRequired, isFalse);
      d = d.setField(f, 50);
    }
    expect(d.hasAllRequired, isTrue);
  });

  test('missing thigh alone keeps the set incomplete', () {
    var d = const MeasurementsDraft();
    for (final f in [
      MeasurementField.height,
      MeasurementField.shoulders,
      MeasurementField.chest,
      MeasurementField.waist,
      MeasurementField.inseam,
      MeasurementField.hips,
    ]) {
      d = d.setField(f, 50);
    }
    expect(d.hasAllRequired, isFalse, reason: 'thigh_cm is required by backend');
    expect(d.setField(MeasurementField.thigh, 56).hasAllRequired, isTrue);
  });

  test('toJson carries all keys; weight_kg null when unset; unit_system echoed', () {
    final d = const MeasurementsDraft()
        .setField(MeasurementField.height, 175, unitSystem: 'imperial')
        .setField(MeasurementField.thigh, 56);
    final json = d.toJson();
    expect(json['height_cm'], 175);
    expect(json['thigh_cm'], 56);
    expect(json['weight_kg'], isNull);
    expect(json.containsKey('weight_kg'), isTrue);
    expect(json['unit_system'], 'imperial');
  });

  test('formatMeasurement trims a trailing .0', () {
    expect(formatMeasurement(175), '175');
    expect(formatMeasurement(96.5), '96.5');
  });
}
