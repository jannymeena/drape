import 'dart:math' as math;

import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';
import 'shape_finder_controller.dart';

/// Body shape from tape measurements, worked out on the device.
///
/// Two numbers describe a silhouette:
///  * **balance**: how much broader the upper body is than the hips,
///    `(upper − hips) / max(upper, hips)`. Positive is top-heavy.
///  * **waist**: the waist against the average of upper body and hips. Lower
///    means a more defined waist; around 1 or above, the waist is the
///    fullest part.
///
/// Each shape is a typical point on those two axes, and the measurements are
/// matched to the nearest ones within the user's shape set (women's has no
/// Trapezoid, men's and neutral no Hourglass). The nearest is the
/// suggestion and the next two the alternatives.
///
/// The upper body is the bust/chest, or, when the optional shoulder width is
/// given, the chest averaged with that width scaled up to a girth: a
/// straight-across shoulder width is roughly 1/[shoulderGirthFactor] of the
/// girth around the shoulders.
ShapeEstimate shapeFromMeasurements(
  BodyShapeSet set,
  Map<MeasurementField, double> cm,
) {
  final chest = cm[MeasurementField.chest];
  final waist = cm[MeasurementField.waist];
  final hips = cm[MeasurementField.hips];
  if (chest == null || waist == null || hips == null) {
    throw ArgumentError('chest, waist and hips are required');
  }
  final s = shapeSignals(cm);

  final allowed = {for (final o in bodyShapesFor(set)) o.value};
  final ranked = [
    for (final p in _prototypes)
      if (allowed.contains(p.shape)) (p.shape, p.distanceTo(s)),
  ]..sort((a, b) => a.$2.compareTo(b.$2));

  return ShapeEstimate(
    best: ranked.first.$1,
    alternatives: [for (final r in ranked.skip(1).take(2)) r.$1],
  );
}

/// Shoulder width × this ≈ shoulder girth.
const shoulderGirthFactor = 2.4;

/// The two numbers the shape is read from; see [shapeFromMeasurements].
({double balance, double waist}) shapeSignals(
  Map<MeasurementField, double> cm,
) {
  final chest = cm[MeasurementField.chest]!;
  final shoulders = cm[MeasurementField.shoulders];
  final upper = shoulders == null
      ? chest
      : (chest + shoulders * shoulderGirthFactor) / 2;
  final hips = cm[MeasurementField.hips]!;
  final waist = cm[MeasurementField.waist]!;
  return (
    balance: (upper - hips) / math.max(upper, hips),
    waist: waist / ((upper + hips) / 2),
  );
}

class _Prototype {
  const _Prototype(this.shape, this.balance, this.waist);

  final String shape;
  final double balance;
  final double waist;

  // How far apart counts as "different" on each axis: 6% on balance (about
  // the size-chart gap between bust and hips that tips a shape), 8% on the
  // waist ratio.
  static const _balanceScale = 0.06;
  static const _waistScale = 0.08;

  double distanceTo(({double balance, double waist}) s) {
    final db = (s.balance - balance) / _balanceScale;
    final dw = (s.waist - waist) / _waistScale;
    return math.sqrt(db * db + dw * dw);
  }
}

const _prototypes = [
  // Upper body and hips alike, waist clearly narrower.
  _Prototype('hourglass', 0, 0.72),
  // Upper body and hips alike, little waist.
  _Prototype('rectangle', 0, 0.86),
  // Hips broader than the upper body.
  _Prototype('triangle', -0.12, 0.82),
  // Upper body a little broader than the hips (men's / neutral).
  _Prototype('trapezoid', 0.08, 0.85),
  // Upper body much broader than the hips.
  _Prototype('inverted_triangle', 0.16, 0.82),
  // The waist is the fullest part.
  _Prototype('oval', 0, 1.02),
];
