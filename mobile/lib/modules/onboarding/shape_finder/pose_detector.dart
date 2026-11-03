import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// MediaPipe's 33 pose landmarks, the ones the shape finder uses.
/// Left/right are the person's own.
abstract final class PosePoint {
  static const nose = 0;
  static const leftEyeOuter = 3;
  static const rightEyeOuter = 6;
  static const leftEar = 7;
  static const rightEar = 8;
  static const leftShoulder = 11;
  static const rightShoulder = 12;
  static const leftElbow = 13;
  static const rightElbow = 14;
  static const leftWrist = 15;
  static const rightWrist = 16;
  static const leftHip = 23;
  static const rightHip = 24;
  static const leftKnee = 25;
  static const rightKnee = 26;
  static const leftAnkle = 27;
  static const rightAnkle = 28;

  /// Nose to the mouth corners: the face.
  static const face = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
}

class PoseLandmark {
  const PoseLandmark(this.x, this.y, {this.visibility = 1, this.presence = 1});

  /// Fractions of the image's width and height; can fall outside 0–1 when
  /// the model places a point beyond the frame.
  final double x;
  final double y;

  /// How likely the point is visible (not hidden) and in the image, 0–1.
  final double visibility;
  final double presence;

  Offset get offset => Offset(x, y);

  bool get inFrame => x >= 0 && x <= 1 && y >= 0 && y <= 1;

  /// Seen, and inside the photo.
  bool get seen => visibility >= 0.5 && inFrame;
}

/// Which pixels are the person: one byte per pixel, row by row, 255 = body.
class BodyMask {
  const BodyMask(this.width, this.height, this.pixels);

  final int width;
  final int height;
  final Uint8List pixels;

  bool isBody(int x, int y) => pixels[y * width + x] >= 128;
}

class DetectedPose {
  const DetectedPose(this.landmarks, this.mask);

  /// All 33, indexed by [PosePoint].
  final List<PoseLandmark> landmarks;
  final BodyMask? mask;

  PoseLandmark operator [](int i) => landmarks[i];
}

/// Finds people in a photo, on the device.
abstract class PoseDetector {
  /// Every person found (none, one, or more). Throws on a photo that can't
  /// be decoded or a detector failure.
  Future<List<DetectedPose>> detect(XFile photo);
}

/// MediaPipe Pose Landmarker through `PoseDetectorChannel` (Kotlin / Swift).
///
/// Flutter decodes the photo, so EXIF orientation is applied exactly as on
/// screen, and scales it to [maxSide]: the model reads at 256 px anyway, and
/// the mask comes back at the size sent.
class MediaPipePoseDetector implements PoseDetector {
  const MediaPipePoseDetector();

  static const _channel = MethodChannel('style.zoura.mobile/pose');
  static const maxSide = 1024;

  @override
  Future<List<DetectedPose>> detect(XFile photo) async {
    final (rgba, width, height) = await _rgba(photo);
    final reply = await _channel.invokeMapMethod<String, Object?>('detect', {
      'rgba': rgba,
      'width': width,
      'height': height,
    });
    return [
      for (final pose in (reply?['poses'] as List?) ?? const [])
        _pose((pose as Map).cast<String, Object?>()),
    ];
  }

  static DetectedPose _pose(Map<String, Object?> pose) {
    final values = pose['landmarks']! as Float64List;
    final mask = pose['mask'] as Uint8List?;
    return DetectedPose(
      [
        for (var i = 0; i + 3 < values.length; i += 4)
          PoseLandmark(
            values[i],
            values[i + 1],
            visibility: values[i + 2],
            presence: values[i + 3],
          ),
      ],
      mask == null
          ? null
          : BodyMask(
              pose['maskWidth']! as int,
              pose['maskHeight']! as int,
              mask,
            ),
    );
  }

  static Future<(Uint8List, int, int)> _rgba(XFile photo) async {
    final codec = await ui.instantiateImageCodec(await photo.readAsBytes());
    var image = (await codec.getNextFrame()).image;
    codec.dispose();
    final scale = math.min(1.0, maxSide / math.max(image.width, image.height));
    // MediaPipe can only hand back the body mask when its rows are
    // contiguous: a width that's a multiple of 4 (4-byte floats, 16-byte
    // rows). Squeezing by up to 3 px changes every width equally, so the
    // ratios the shape comes from don't move.
    final w = math.max(4, (image.width * scale) ~/ 4 * 4);
    final h = (image.height * scale).round();
    if (w != image.width || h != image.height) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium,
      );
      final scaled = await recorder.endRecording().toImage(w, h);
      image.dispose();
      image = scaled;
    }
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final size = (image.width, image.height);
    image.dispose();
    return (bytes!.buffer.asUint8List(), size.$1, size.$2);
  }
}

final poseDetectorProvider = Provider<PoseDetector>(
  (ref) => const MediaPipePoseDetector(),
);
