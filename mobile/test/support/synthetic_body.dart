import 'dart:math' as math;
import 'dart:typed_data';

import 'package:mobile/modules/onboarding/shape_finder/pose_detector.dart';

/// A stick-and-blob person, 200 × 400 px, standing face on, for testing
/// what's read from MediaPipe's output without running the model.
///
/// Torso half-widths: 40 px at the shoulders (y 80–84), narrowing to 25 at
/// the waist (y 150), widening to 35 at the hips (y 190–220). The arms hang
/// straight down, [armGap] px clear of the hips; 0 lets them touch there
/// (and overlap the chest just below the shoulders). With
/// [handsInFront] the wrists' landmarks are over the middle of the body, as
/// with hands clasped in front.
DetectedPose syntheticBody({
  double armGap = 8,
  double shoulderSpan = 64,
  bool feet = true,
  bool handsInFront = false,
}) {
  const w = 200, h = 400, cx = 100.0;
  final pixels = Uint8List(w * h);

  double? torsoHalf(double y) {
    if (y < 65 || y >= 220) return null;
    if (y < 80) return 30 + (y - 65) / 15 * 10;
    if (y < 85) return 40;
    if (y < 150) return 40 - (y - 85) / 65 * 15;
    if (y < 190) return 25 + (y - 150) / 40 * 10;
    return 35;
  }

  // The arm's bone line: straight down beside the body, 12 px thick.
  double armX(double y, int side) => cx + side * (35 + armGap + 6);

  void fill(int x, int y) {
    if (x >= 0 && x < w && y >= 0 && y < h) pixels[y * w + x] = 255;
  }

  for (var y = 0; y < h; y++) {
    final yy = y.toDouble();
    // Head and neck.
    if (yy >= 25 && yy < 55) {
      final dy = yy - 40;
      final half = math.sqrt(math.max(0, 225 - dy * dy));
      for (var x = (cx - half).round(); x <= (cx + half).round(); x++) {
        fill(x, y);
      }
    }
    if (yy >= 55 && yy < 65) {
      for (var x = 93; x <= 107; x++) {
        fill(x, y);
      }
    }
    final half = torsoHalf(yy);
    if (half != null) {
      for (var x = (cx - half).round(); x <= (cx + half).round(); x++) {
        fill(x, y);
      }
    }
    // Arms, 12 px thick, from below the shoulders to the hands.
    if (yy >= 85 && yy < 215) {
      for (final side in [-1, 1]) {
        final ax = armX(yy, side);
        for (var x = (ax - 6).round(); x <= (ax + 6).round(); x++) {
          fill(x, y);
        }
      }
    }
    // Legs.
    if (yy >= 220 && yy < (feet ? 385 : 400)) {
      for (final lx in [cx - 15, cx + 15]) {
        for (var x = (lx - 13).round(); x <= (lx + 13).round(); x++) {
          fill(x, y);
        }
      }
    }
  }

  PoseLandmark at(double x, double y) => PoseLandmark(x / w, y / h);
  final points = List<PoseLandmark>.filled(33, at(cx, 300));
  void put(int i, double x, double y) => points[i] = at(x, y);
  // The person's left is the image's right.
  put(PosePoint.nose, cx, 42);
  put(1, cx + 4, 38);
  put(2, cx + 6, 38);
  put(PosePoint.leftEyeOuter, cx + 8, 38);
  put(4, cx - 4, 38);
  put(5, cx - 6, 38);
  put(PosePoint.rightEyeOuter, cx - 8, 38);
  put(PosePoint.leftEar, cx + 15, 40);
  put(PosePoint.rightEar, cx - 15, 40);
  put(9, cx + 5, 50);
  put(10, cx - 5, 50);
  put(PosePoint.leftShoulder, cx + shoulderSpan / 2, 80);
  put(PosePoint.rightShoulder, cx - shoulderSpan / 2, 80);
  put(PosePoint.leftElbow, armX(140, 1), 140);
  put(PosePoint.rightElbow, armX(140, -1), 140);
  put(PosePoint.leftWrist, handsInFront ? cx + 5 : armX(200, 1), 200);
  put(PosePoint.rightWrist, handsInFront ? cx - 5 : armX(200, -1), 200);
  put(PosePoint.leftHip, cx + 22, 185);
  put(PosePoint.rightHip, cx - 22, 185);
  put(PosePoint.leftKnee, cx + 15, 280);
  put(PosePoint.rightKnee, cx - 15, 280);
  put(PosePoint.leftAnkle, cx + 15, feet ? 370 : 420);
  put(PosePoint.rightAnkle, cx - 15, feet ? 370 : 420);

  return DetectedPose(points, BodyMask(w, h, pixels));
}

/// Answers with [poses], without a model.
class FakePoseDetector implements PoseDetector {
  FakePoseDetector([List<DetectedPose>? poses])
    : poses = poses ?? [syntheticBody()];

  List<DetectedPose> poses;

  @override
  Future<List<DetectedPose>> detect(_) async => poses;
}
