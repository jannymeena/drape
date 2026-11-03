import 'dart:io';
import 'dart:isolate';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import '../../../shared/theme/app_colors.dart';
import 'shape_finder_controller.dart';

/// Makes the photo the shape finder works from after "Use This Photo": the
/// original with the face blur and the framing guide drawn into it.
abstract class ShapePhotoRenderer {
  /// A new image, the size of [original]: [faceBlur]'s circle blurred (none
  /// when null) and [guides]' lines and labels drawn across. Throws
  /// [PhotoUnreadableException] when [original] can't be decoded.
  Future<XFile> render(
    XFile original, {
    required FramingGuides guides,
    FaceBlur? faceBlur,
  });

  /// Deletes an image [render] made, once it's no longer needed.
  Future<void> discard(XFile framed);
}

/// Draws with dart:ui at the photo's own resolution and encodes a JPEG off
/// the UI isolate. The JPEG carries no EXIF, so the original's location and
/// camera details go no further; orientation is already applied on decode.
class CanvasShapePhotoRenderer implements ShapePhotoRenderer {
  const CanvasShapePhotoRenderer({this.directory = getTemporaryDirectory});

  /// Where the new image is written.
  final Future<Directory> Function() directory;

  /// The on-screen frame is about this many points wide; the review screen's
  /// blur strength, line weights and label sizes are scaled from it, so the
  /// image looks like what the user saw.
  static const _frameWidth = 360.0;

  @override
  Future<XFile> render(
    XFile original, {
    required FramingGuides guides,
    FaceBlur? faceBlur,
  }) async {
    final ui.Image photo;
    try {
      final codec = await ui.instantiateImageCodec(
        await original.readAsBytes(),
      );
      photo = (await codec.getNextFrame()).image;
      codec.dispose();
    } on Exception {
      throw const PhotoUnreadableException();
    }

    final w = photo.width.toDouble();
    final h = photo.height.toDouble();
    final s = w / _frameWidth;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
    canvas.drawImage(photo, Offset.zero, Paint());
    if (faceBlur != null) _blur(canvas, photo, faceBlur, w, h, s);
    for (final l in Landmark.values) {
      _guide(canvas, _labels[l]!, guides[l] * h, w, s);
    }

    final framed = await recorder.endRecording().toImage(
      photo.width,
      photo.height,
    );
    final rgba = await framed.toByteData(format: ui.ImageByteFormat.rawRgba);
    photo.dispose();
    framed.dispose();
    if (rgba == null) throw const PhotoUnreadableException();

    final width = framed.width;
    final height = framed.height;
    final pixels = TransferableTypedData.fromList([rgba.buffer.asUint8List()]);
    final jpeg = await Isolate.run(
      () => img.encodeJpg(
        img.Image.fromBytes(
          width: width,
          height: height,
          bytes: pixels.materialize(),
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        ),
        quality: 90,
      ),
    );

    final dir = await directory();
    final file = File(
      '${dir.path}/shape_photo_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(jpeg, flush: true);
    return XFile(file.path, mimeType: 'image/jpeg');
  }

  @override
  Future<void> discard(XFile framed) async {
    try {
      await File(framed.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  static const _labels = {
    Landmark.shoulders: 'Shoulders',
    Landmark.waist: 'Waist',
    Landmark.hips: 'Hips',
  };

  /// The photo, blurred, inside the circle, with the same light frost as on
  /// screen. No border: that's only there while the circle is being placed.
  static void _blur(
    Canvas canvas,
    ui.Image photo,
    FaceBlur blur,
    double w,
    double h,
    double s,
  ) {
    final circle = Rect.fromCircle(
      center: Offset(blur.center.dx * w, blur.center.dy * h),
      radius: blur.radius * w,
    );
    final sigma = 16 * s;
    canvas
      ..save()
      ..clipPath(Path()..addOval(circle))
      ..drawImage(
        photo,
        Offset.zero,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      )
      ..drawRect(
        circle,
        Paint()..color = AppColors.white.withValues(alpha: 0.15),
      )
      ..restore();
  }

  /// A dashed gold line at [y] with end dots and its name in a white chip at
  /// the left, as on the review screen.
  static void _guide(
    Canvas canvas,
    String label,
    double y,
    double w,
    double s,
  ) {
    final gold = Paint()
      ..color = AppColors.goldSoft
      ..strokeWidth = 1.5 * s;
    for (var x = 24 * s; x < w - 24 * s; x += 8 * s) {
      canvas.drawLine(Offset(x, y), Offset(x + 4 * s, y), gold);
    }
    canvas
      ..drawCircle(Offset(20 * s, y), 4 * s, gold)
      ..drawCircle(Offset(w - 20 * s, y), 4 * s, gold);

    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: 10.5 * s,
          fontWeight: FontWeight.w600,
          color: AppColors.espressoDark,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final chip = Rect.fromLTWH(
      30 * s,
      y - text.height / 2 - 4 * s,
      text.width + 20 * s,
      text.height + 8 * s,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, Radius.circular(chip.height / 2)),
      Paint()..color = AppColors.white.withValues(alpha: 0.92),
    );
    text
      ..paint(canvas, Offset(chip.left + 10 * s, chip.top + 4 * s))
      ..dispose();
  }
}

final shapePhotoRendererProvider = Provider<ShapePhotoRenderer>(
  (ref) => const CanvasShapePhotoRenderer(),
);
