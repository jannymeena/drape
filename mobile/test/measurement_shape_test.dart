import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/body_shapes.dart';
import 'package:mobile/modules/onboarding/models/measurements_draft.dart';
import 'package:mobile/modules/onboarding/shape_finder/measurement_shape.dart';

Map<MeasurementField, double> _cm(
  double chest,
  double waist,
  double hips, {
  double? shoulders,
}) => {
  MeasurementField.chest: chest,
  MeasurementField.waist: waist,
  MeasurementField.hips: hips,
  MeasurementField.shoulders: ?shoulders,
};

String _best(BodyShapeSet set, Map<MeasurementField, double> cm) =>
    shapeFromMeasurements(set, cm).best;

void main() {
  const w = BodyShapeSet.womens;
  const m = BodyShapeSet.mens;
  const n = BodyShapeSet.neutral;

  group("women's", () {
    test('bust ≈ hips with a defined waist is an hourglass', () {
      expect(_best(w, _cm(92, 70, 98)), 'hourglass');
      expect(_best(w, _cm(96, 72, 96)), 'hourglass');
    });

    test('hips clearly broader than the bust is a pear', () {
      expect(_best(w, _cm(88, 74, 104)), 'triangle');
    });

    test('bust ≈ hips with little waist is a rectangle', () {
      expect(_best(w, _cm(88, 76, 90)), 'rectangle');
    });

    test('bust and shoulders clearly broader than the hips', () {
      expect(_best(w, _cm(102, 80, 88)), 'inverted_triangle');
    });

    test('a waist as full as bust and hips is an oval', () {
      expect(_best(w, _cm(104, 106, 104)), 'oval');
    });
  });

  group("men's", () {
    test('chest ≈ hips, straight through the waist, is a rectangle', () {
      expect(_best(m, _cm(100, 86, 98)), 'rectangle');
    });

    test('broad shoulders tip a moderate frame into a trapezoid', () {
      expect(_best(m, _cm(100, 86, 98, shoulders: 48)), 'trapezoid');
    });

    test('a much broader chest and shoulders is an inverted triangle', () {
      expect(_best(m, _cm(110, 82, 98, shoulders: 52)), 'inverted_triangle');
    });

    test('a waist fuller than the chest is an oval', () {
      expect(_best(m, _cm(108, 110, 104)), 'oval');
    });

    test('hips broader than the chest is a triangle', () {
      expect(_best(m, _cm(94, 88, 106)), 'triangle');
    });
  });

  test('only shapes the set offers are suggested', () {
    // An hourglass figure, entered under the men's and neutral sets (no
    // Hourglass there), and a trapezoid under the women's (no Trapezoid).
    for (final (set, cm) in [
      (m, _cm(96, 70, 96)),
      (n, _cm(96, 70, 96)),
      (w, _cm(100, 86, 98, shoulders: 48)),
    ]) {
      final e = shapeFromMeasurements(set, cm);
      final offered = {for (final o in bodyShapesFor(set)) o.value};
      expect(offered, containsAll([e.best, ...e.alternatives]));
      expect(e.alternatives, hasLength(2));
      expect(e.alternatives, isNot(contains(e.best)));
    }
    expect(_best(m, _cm(96, 70, 96)), isNot('hourglass'));
    expect(_best(w, _cm(100, 86, 98, shoulders: 48)), isNot('trapezoid'));
  });

  test('the runners-up are the next closest shapes', () {
    // A pear that's nearly balanced: rectangle or hourglass come next, not
    // the top-heavy shapes.
    final e = shapeFromMeasurements(w, _cm(90, 74, 100));
    expect(e.best, 'triangle');
    expect(e.alternatives, isNot(contains('inverted_triangle')));
  });

  test('chest, waist and hips are required', () {
    expect(
      () => shapeFromMeasurements(w, {
        MeasurementField.chest: 90,
        MeasurementField.hips: 96,
      }),
      throwsArgumentError,
    );
  });
}
