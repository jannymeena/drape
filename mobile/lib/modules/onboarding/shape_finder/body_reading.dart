import 'dart:math' as math;
import 'dart:ui' show Offset, lerpDouble;

import '../models/body_shapes.dart';
import 'measurement_shape.dart';
import 'pose_detector.dart';
import 'shape_finder_controller.dart';

/// Why a photo can't be read; the error screen explains each.
enum PhotoProblem {
  /// Couldn't be decoded, or the detector failed.
  unreadable,
  noPerson,
  severalPeople,

  /// Shoulders, hips or feet are out of the shot.
  notFullBody,

  /// Turned sideways: a front view is needed to see widths.
  sideOn,

  /// An arm touches the body at the waist or hips line, so the body's edge
  /// there can't be told from the arm's.
  armsTouching,
}

/// The photo doesn't show a body that can be read.
class PhotoUnreadableException implements Exception {
  const PhotoUnreadableException([this.problem = PhotoProblem.unreadable]);

  final PhotoProblem problem;

  @override
  String toString() => 'PhotoUnreadableException(${problem.name})';
}

/// The body's width at each framing line, as fractions of the photo's width.
typedef BodyWidths = ({double shoulders, double waist, double hips});

/// One person found in the photo (see [PoseDetector]), checked and ready to
/// measure. Everything is in fractions of the photo, the units of
/// [FramingGuides] and [FaceBlur].
class BodyReading {
  BodyReading._(this._pose, this._mask);

  final DetectedPose _pose;
  final BodyMask _mask;

  /// The only person in [poses], if they can be measured: one person,
  /// head to feet in the shot, facing the camera. Throws
  /// [PhotoUnreadableException] saying what's wrong.
  factory BodyReading.from(List<DetectedPose> poses) {
    if (poses.isEmpty) {
      throw const PhotoUnreadableException(PhotoProblem.noPerson);
    }
    if (poses.length > 1) {
      throw const PhotoUnreadableException(PhotoProblem.severalPeople);
    }
    final pose = poses.single;
    final mask = pose.mask;
    if (mask == null || pose.landmarks.length < 33) {
      throw const PhotoUnreadableException();
    }
    // The face may be left out of the shot (the tips say so); the body from
    // the shoulders to the feet may not.
    const core = [
      PosePoint.leftShoulder,
      PosePoint.rightShoulder,
      PosePoint.leftHip,
      PosePoint.rightHip,
    ];
    final feet =
        pose[PosePoint.leftAnkle].seen || pose[PosePoint.rightAnkle].seen;
    if (!core.every((i) => pose[i].seen) || !feet) {
      throw const PhotoUnreadableException(PhotoProblem.notFullBody);
    }
    final reading = BodyReading._(pose, mask);
    // Face on, the shoulder joints are about 3/4 of the torso's length
    // apart; turned sideways they close up.
    if (reading._shoulderSpan < 0.4 * reading._torsoLength) {
      throw const PhotoUnreadableException(PhotoProblem.sideOn);
    }
    return reading;
  }

  // ─── Landmarks, in pixels of the mask ─────────────────────────────────

  Offset _px(int i) =>
      Offset(_pose[i].x * _mask.width, _pose[i].y * _mask.height);

  Offset _mid(int a, int b) => (_px(a) + _px(b)) / 2;

  Offset get _midShoulder =>
      _mid(PosePoint.leftShoulder, PosePoint.rightShoulder);
  Offset get _midHip => _mid(PosePoint.leftHip, PosePoint.rightHip);

  double get _shoulderSpan =>
      (_px(PosePoint.leftShoulder) - _px(PosePoint.rightShoulder)).distance;
  double get _torsoLength => (_midShoulder - _midHip).distance;

  // Heights as fractions of the photo.
  double get _shoulderY => _midShoulder.dy / _mask.height;
  double get _hipY => _midHip.dy / _mask.height;
  double get _kneeY {
    final l = _pose[PosePoint.leftKnee];
    final r = _pose[PosePoint.rightKnee];
    if (l.seen || r.seen) {
      return l.seen && r.seen ? (l.y + r.y) / 2 : (l.seen ? l.y : r.y);
    }
    return _hipY + (_hipY - _shoulderY) * 0.9;
  }

  // ─── Suggestions for the review screen ────────────────────────────────

  /// Where the lines start: the shoulder line just under the shoulder
  /// joints, where the shoulders are broadest; the waist line at the
  /// narrowest point between shoulders and hips; the hips line at the
  /// broadest point around the hip joints.
  FramingGuides get suggestedGuides {
    final torso = _hipY - _shoulderY;
    final shoulders = _shoulderY + 0.04 * torso;
    final waist =
        _extremeRow(
          from: _shoulderY + 0.45 * torso,
          to: _shoulderY + 0.85 * torso,
          widest: false,
        ) ??
        _shoulderY + 0.62 * torso;
    final hips =
        _extremeRow(
          from: _hipY - 0.05 * torso,
          to: _hipY + 0.25 * (_kneeY - _hipY),
          widest: true,
        ) ??
        _hipY + 0.08 * (_kneeY - _hipY);
    return FramingGuides.fitted(shoulders: shoulders, waist: waist, hips: hips);
  }

  /// A circle over the face: centred on the face's landmarks, raised a
  /// little for the forehead and hair, and a face's width across (ear to
  /// ear, doubled) so the hair around the face is covered too.
  FaceBlur get suggestedFaceBlur {
    final seen = [
      for (final i in PosePoint.face)
        if (_pose[i].seen) _px(i),
    ];
    // No face in the shot: just above the shoulders, where it would be.
    final centre = seen.isEmpty
        ? _midShoulder.translate(0, -0.6 * _shoulderSpan)
        : seen.reduce((a, b) => a + b) / seen.length.toDouble();

    double? span(int a, int b) =>
        _pose[a].seen && _pose[b].seen ? (_px(a) - _px(b)).distance : null;
    final ears = span(PosePoint.leftEar, PosePoint.rightEar);
    final eyes = span(PosePoint.leftEyeOuter, PosePoint.rightEyeOuter);
    final faceWidth = ears ?? (eyes != null ? eyes * 1.4 : _shoulderSpan * 0.5);

    final raised = centre.translate(0, -0.15 * faceWidth);
    return FaceBlur(
      center: Offset(
        (raised.dx / _mask.width).clamp(0.0, 1.0),
        (raised.dy / _mask.height).clamp(0.0, 1.0),
      ),
    ).resize(faceWidth / _mask.width);
  }

  // ─── Measuring ────────────────────────────────────────────────────────

  /// The body's width at each of [guides]' lines. Throws
  /// [PhotoUnreadableException]: [PhotoProblem.notFullBody] when a line
  /// misses the body, or [PhotoProblem.armsTouching] when an arm at the
  /// waist or hips line can't be told apart from the body.
  BodyWidths widthsAt(FramingGuides guides) {
    final shoulders = _torsoRun(guides.shoulders);
    if (shoulders == null) {
      throw const PhotoUnreadableException(PhotoProblem.notFullBody);
    }
    return (
      // At shoulder height the upper arms are part of the shoulders' width.
      shoulders: shoulders.width / _mask.width,
      waist: _torsoWidth(guides.waist) / _mask.width,
      hips: _torsoWidth(guides.hips) / _mask.width,
    );
  }

  /// The torso's width in pixels across row [y] (a fraction of the height),
  /// without the arms.
  ///
  /// Arms hanging close to the body often merge with it in the mask. Where
  /// an arm's bone line runs inside the body's stretch, the stretch's edge on
  /// that side is the arm's outer edge, so the arm's own thickness (measured
  /// where it hangs clear, see [_armWidth]) is cut off there.
  ///
  /// Throws [PhotoUnreadableException]: [PhotoProblem.notFullBody] when the
  /// row misses the body; [PhotoProblem.armsTouching] when an arm isn't
  /// hanging at the side (it's nearer the middle than the hip joints, as
  /// with hands clasped in front), what's cut off is too wide to be an arm
  /// (a hand on the hip, elbow out), or too little body is left.
  double _torsoWidth(double y) {
    final run = _torsoRun(y);
    if (run == null) {
      throw const PhotoUnreadableException(PhotoProblem.notFullBody);
    }
    const armsTouching = PhotoUnreadableException(PhotoProblem.armsTouching);
    final widestArm = 0.25 * _shoulderSpan;
    final hipHalf =
        (_px(PosePoint.leftHip).dx - _px(PosePoint.rightHip).dx).abs() / 2;
    var left = run.left.toDouble();
    var right = run.right.toDouble();
    for (final (x, side) in run.arms) {
      if ((x - run.centre).abs() < 0.9 * hipHalf) throw armsTouching;
      // From the bone line out to the edge is half the arm or less; more,
      // and something else (an elbow out, a bag) is merged too.
      final outer = x < run.centre ? x - left : right - x;
      if (outer > widestArm) throw armsTouching;
      final arm = _armWidth(side);
      if (x < run.centre) {
        left += arm;
      } else {
        right -= arm;
      }
    }
    if (right - left < 0.3 * _shoulderSpan) throw armsTouching;
    return right - left + 1;
  }

  /// The row between [from] and [to] (fractions of the height) where the
  /// torso is narrowest, or with [widest] broadest. Null when no row can be
  /// read.
  double? _extremeRow({
    required double from,
    required double to,
    required bool widest,
  }) {
    final top = (from * _mask.height).round().clamp(0, _mask.height - 1);
    final bottom = (to * _mask.height).round().clamp(0, _mask.height - 1);
    int? best;
    var bestWidth = 0.0;
    for (var row = top; row <= bottom; row++) {
      final double width;
      try {
        width = _torsoWidth((row + 0.5) / _mask.height);
      } on PhotoUnreadableException {
        continue;
      }
      if (best == null || (widest ? width > bestWidth : width < bestWidth)) {
        best = row;
        bestWidth = width;
      }
    }
    return best == null ? null : (best + 0.5) / _mask.height;
  }

  /// The stretch of body pixels across row [y] (a fraction of the height)
  /// that contains the body's centre line, which runs from between the
  /// shoulders to between the hips, with the arms whose bone lines run
  /// inside it. Null when the row misses the body.
  _Run? _torsoRun(double y) {
    final w = _mask.width;
    final row = (y * _mask.height).floor().clamp(0, _mask.height - 1);
    final t = ((row - _midShoulder.dy) / (_midHip.dy - _midShoulder.dy)).clamp(
      0.0,
      1.0,
    );
    final centre = lerpDouble(_midShoulder.dx, _midHip.dx, t)!;

    // Start on the centre line, or the nearest body pixel close to it.
    int? start;
    final reach = (0.05 * w).round();
    for (var d = 0; d <= reach && start == null; d++) {
      for (final x in [centre.round() - d, centre.round() + d]) {
        if (x >= 0 && x < w && _mask.isBody(x, row)) {
          start = x;
          break;
        }
      }
    }
    if (start == null) return null;
    var left = start;
    var right = start;
    while (left > 0 && _mask.isBody(left - 1, row)) {
      left--;
    }
    while (right < w - 1 && _mask.isBody(right + 1, row)) {
      right++;
    }

    final arms = [
      for (final side in _Side.values)
        if (_armX(row + 0.5, side) case final x? when x >= left && x <= right)
          (x, side),
    ];
    return _Run(left, right, centre: centre, arms: arms);
  }

  /// How thick [side]'s arm is, in pixels: the median width of the arm's
  /// own stretch of body pixels, on the rows below the armpit where it hangs
  /// clear of the torso. With no such row, a typical arm for the shoulders.
  double _armWidth(_Side side) =>
      _armWidths[side] ??= _measureArm(side) ?? 0.2 * _shoulderSpan;

  final _armWidths = <_Side, double>{};

  double? _measureArm(_Side side) {
    final widths = <int>[];
    for (var row = 0; row < _mask.height; row++) {
      final x = _armX(row + 0.5, side)?.round();
      if (x == null || x < 0 || x >= _mask.width || !_mask.isBody(x, row)) {
        continue;
      }
      final torso = _torsoRun((row + 0.5) / _mask.height);
      if (torso != null && x >= torso.left && x <= torso.right) continue;
      var l = x;
      var r = x;
      while (l > 0 && _mask.isBody(l - 1, row)) {
        l--;
      }
      while (r < _mask.width - 1 && _mask.isBody(r + 1, row)) {
        r++;
      }
      // Wider than an arm could be: something else is joined to it.
      if (r - l + 1 <= 0.3 * _shoulderSpan) widths.add(r - l + 1);
    }
    if (widths.length < 3) return null;
    widths.sort();
    return widths[widths.length ~/ 2].toDouble();
  }

  /// Where [side]'s arm's bone line (shoulder → elbow → wrist → hand)
  /// crosses pixel row [row], if it does below the armpit.
  double? _armX(double row, _Side side) {
    final armpit = _midShoulder.dy + 0.15 * (_midHip.dy - _midShoulder.dy);
    if (row < armpit) return null;
    final s = _px(side.shoulder);
    final e = _px(side.elbow);
    final wr = _px(side.wrist);
    // A hand is about 3/4 as long as the forearm.
    final hand = wr + (wr - e) * 0.75;
    for (final (a, b) in [(s, e), (e, wr), (wr, hand)]) {
      final lo = math.min(a.dy, b.dy);
      final hi = math.max(a.dy, b.dy);
      if (row < lo || row > hi || hi == lo) continue;
      return lerpDouble(a.dx, b.dx, (row - a.dy) / (b.dy - a.dy));
    }
    return null;
  }
}

/// The person's own left and right.
enum _Side {
  left(PosePoint.leftShoulder, PosePoint.leftElbow, PosePoint.leftWrist),
  right(PosePoint.rightShoulder, PosePoint.rightElbow, PosePoint.rightWrist);

  const _Side(this.shoulder, this.elbow, this.wrist);

  final int shoulder;
  final int elbow;
  final int wrist;
}

class _Run {
  const _Run(this.left, this.right, {required this.centre, required this.arms});

  final int left;
  final int right;

  /// The body's centre line at this row, in pixels.
  final double centre;

  /// Where arms' bone lines cross this row inside the stretch, in pixels.
  final List<(double, _Side)> arms;

  int get width => right - left + 1;
}

// ─── Widths → shape ────────────────────────────────────────────────────────

/// Front-view widths scaled to girths, for [shapeFromSignals]. A photo has
/// no real scale, but only the ratios between the three matter.
///
/// The factors are typical adult girth-to-width ratios: bust/chest girth
/// over the width across the shoulders (upper arms included, as the photo
/// sees them), and waist and hip girth over their front widths. The upper
/// body's is per set, since men are broader across the shoulders for their
/// chest girth than women. They're set so that an average figure reads as
/// average (a woman's bust about her hips; a man's chest a little broader).
///
/// Estimates from typical body proportions, not yet calibrated: that needs
/// photos of people whose tape measurements are known.
ShapeSignals photoSignals(BodyShapeSet set, BodyWidths widths) {
  final upperFactor = switch (set) {
    BodyShapeSet.womens => 2.15,
    BodyShapeSet.mens => 2.05,
    BodyShapeSet.neutral => 2.1,
  };
  return signalsFromGirths(
    upper: widths.shoulders * upperFactor,
    waist: widths.waist * 2.75,
    hips: widths.hips * 2.75,
  );
}
