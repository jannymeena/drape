import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_finder_controller.dart';

/// The user's photo, framed at its own aspect ratio so nothing is cropped —
/// which also makes the frame's fractions the photo's fractions, the units
/// [FramingGuides] and [FaceBlur] are stored in.
///
/// Optionally overlays the shoulder / waist / hip lines and the face-blur
/// disc. With the `on…` callbacks they're editable: drag a line up or down;
/// drag the disc, pinch it, or pull its handle to resize. Those controls
/// claim the finger on touch-down, so the page doesn't scroll from under it.
class ShapePhotoFrame extends StatefulWidget {
  const ShapePhotoFrame({
    super.key,
    required this.file,
    required this.photoSize,
    this.maxHeight = 520,
    this.guides,
    this.faceBlur,
    this.onNudgeGuide,
    this.onMoveFaceBlur,
    this.onGrowFaceBlur,
    this.onScaleFaceBlur,
    this.greyscale = false,
    this.overlays = const [],
    this.badges = const [],
  });

  final File file;

  /// The photo's pixel size; null until read, when a 3:4 frame stands in.
  final Size? photoSize;
  final double maxHeight;

  /// Null hides the lines.
  final FramingGuides? guides;

  /// Null hides the disc.
  final FaceBlur? faceBlur;

  // Editing callbacks report *changes*, never absolute positions: the owner
  // applies them to its latest state (see ShapeFinderController.nudgeGuide).

  /// [dy] is a fraction of the photo's height.
  final void Function(Landmark landmark, double dy)? onNudgeGuide;

  /// [delta] is in fractions of the photo's width and height.
  final ValueChanged<Offset>? onMoveFaceBlur;

  /// [dr] is a fraction of the photo's width (the resize handle).
  final ValueChanged<double>? onGrowFaceBlur;

  /// A pinch, as a factor of the radius.
  final ValueChanged<double>? onScaleFaceBlur;

  final bool greyscale;

  /// Drawn over the photo, under the lines and disc; sized to the frame.
  final List<Widget> overlays;

  /// Pinned to the frame's corners and edges by the caller (`Positioned`).
  final List<Widget> badges;

  @override
  State<ShapePhotoFrame> createState() => _ShapePhotoFrameState();
}

class _ShapePhotoFrameState extends State<ShapePhotoFrame> {
  /// The pinch scale already applied in this gesture.
  double _lastScale = 1;

  static const _labels = {
    Landmark.shoulders: 'Shoulders',
    Landmark.waist: 'Waist',
    Landmark.hips: 'Hips',
  };

  @override
  Widget build(BuildContext context) {
    final size = widget.photoSize;
    final aspect = size == null || size.height == 0
        ? 3 / 4
        : size.width / size.height;
    return LayoutBuilder(
      builder: (context, box) {
        final w = math.min(box.maxWidth, widget.maxHeight * aspect);
        final h = w / aspect;
        // Centred in a wide parent, but no wider than the photo in a loose one
        // (the analyzing screen's card hugs it).
        return Center(
          widthFactor: 1,
          heightFactor: 1,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  Positioned.fill(child: _photo()),
                  for (final o in widget.overlays) Positioned.fill(child: o),
                  if (widget.guides case final guides?)
                    for (final l in Landmark.values)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: h * guides[l] - 22,
                        height: 44,
                        child: _GuideLine(
                          label: _labels[l]!,
                          onDrag: widget.onNudgeGuide == null
                              ? null
                              : (dy) => widget.onNudgeGuide!(l, dy / h),
                        ),
                      ),
                  if (widget.faceBlur case final blur?) ..._disc(blur, w, h),
                  ...widget.badges,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _photo() {
    final image = Image.file(widget.file, fit: BoxFit.cover);
    if (!widget.greyscale) return image;
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          0.33, 0.59, 0.11, 0, 0, //
          0.33, 0.59, 0.11, 0, 0, //
          0.33, 0.59, 0.11, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: image,
      ),
    );
  }

  List<Widget> _disc(FaceBlur blur, double w, double h) {
    final r = blur.radius * w;
    final cx = blur.center.dx * w;
    final cy = blur.center.dy * h;
    final editable = widget.onMoveFaceBlur != null;
    // The resize handle sits on the rim, down and to the right.
    final handle = Offset(cx + r * math.sqrt1_2, cy + r * math.sqrt1_2);

    Widget disc = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white.withValues(alpha: 0.15),
            border: editable
                ? Border.all(
                    color: AppColors.white.withValues(alpha: 0.9),
                    width: 2,
                  )
                : null,
          ),
        ),
      ),
    );
    if (editable) {
      disc = Semantics(
        label: 'Face blur. Drag to move, pinch or use the handle to resize.',
        child: RawGestureDetector(
          gestures: {
            _EagerScale: GestureRecognizerFactoryWithHandlers<_EagerScale>(
              _EagerScale.new,
              (r) => r
                ..onStart = (_) {
                  _lastScale = 1;
                }
                ..onUpdate = (d) {
                  widget.onMoveFaceBlur!(
                    Offset(d.focalPointDelta.dx / w, d.focalPointDelta.dy / h),
                  );
                  if (d.pointerCount > 1 && d.scale > 0) {
                    widget.onScaleFaceBlur?.call(d.scale / _lastScale);
                    _lastScale = d.scale;
                  }
                },
            ),
          },
          child: disc,
        ),
      );
    }

    return [
      Positioned(
        left: cx - r,
        top: cy - r,
        width: r * 2,
        height: r * 2,
        child: disc,
      ),
      if (editable && widget.onGrowFaceBlur != null)
        Positioned(
          left: handle.dx - 16,
          top: handle.dy - 16,
          width: 32,
          height: 32,
          child: RawGestureDetector(
            gestures: {
              _EagerPan: GestureRecognizerFactoryWithHandlers<_EagerPan>(
                _EagerPan.new,
                (p) => p.onUpdate = (d) {
                  // Outward along the diagonal grows the disc.
                  final outward = (d.delta.dx + d.delta.dy) * math.sqrt1_2;
                  widget.onGrowFaceBlur!(outward / w);
                },
              ),
            },
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(color: Color(0x33000000), blurRadius: 4),
                  ],
                ),
                child: const Icon(
                  Icons.open_in_full,
                  size: 12,
                  color: AppColors.espressoDark,
                ),
              ),
            ),
          ),
        ),
    ];
  }
}

/// A dashed line across the photo with its name at the left. With [onDrag]
/// the whole 44-pt band is a drag target, reporting vertical movement.
class _GuideLine extends StatelessWidget {
  const _GuideLine({required this.label, this.onDrag});

  final String label;
  final ValueChanged<double>? onDrag;

  @override
  Widget build(BuildContext context) {
    // The label sits at the line's left end, clear of the face and the blur
    // disc, which are usually mid-photo.
    final line = Stack(
      alignment: AlignmentDirectional.centerStart,
      children: [
        Positioned.fill(child: CustomPaint(painter: _DashedLinePainter())),
        Container(
          margin: const EdgeInsetsDirectional.only(start: 30),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: BlueprintText.caption(context).copyWith(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.espressoDark,
                ),
              ),
              if (onDrag != null) ...[
                const SizedBox(width: 4),
                const Icon(
                  Icons.unfold_more,
                  size: 14,
                  color: AppColors.espressoDark,
                ),
              ],
            ],
          ),
        ),
      ],
    );
    final drag = onDrag;
    if (drag == null) return line;
    return Semantics(
      label: '$label line. Drag up or down to line it up with your $label.',
      child: RawGestureDetector(
        behavior: HitTestBehavior.opaque,
        gestures: {
          _EagerVerticalDrag:
              GestureRecognizerFactoryWithHandlers<_EagerVerticalDrag>(
                _EagerVerticalDrag.new,
                (r) => r.onUpdate = (d) => drag(d.delta.dy),
              ),
        },
        child: line,
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.goldSoft
      ..strokeWidth = 1.5;
    final y = size.height / 2;
    for (var x = 24.0; x < size.width - 24; x += 8) {
      canvas.drawLine(Offset(x, y), Offset(x + 4, y), paint);
    }
    final dot = Paint()..color = AppColors.goldSoft;
    canvas
      ..drawCircle(Offset(20, y), 4, dot)
      ..drawCircle(Offset(size.width - 20, y), 4, dot);
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => false;
}

// Recognizers that win the gesture arena as soon as a finger lands on them,
// so dragging a control on the photo never scrolls the page instead.

class _EagerScale extends ScaleGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _EagerPan extends PanGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

class _EagerVerticalDrag extends VerticalDragGestureRecognizer {
  @override
  void addAllowedPointer(PointerDownEvent event) {
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }
}

/// A small white pill on the photo — a status or a label.
class ShapePhotoChip extends StatelessWidget {
  const ShapePhotoChip({super.key, required this.label, this.leading});

  final String label;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 6)],
          Text(
            label,
            style: BlueprintText.caption(context).copyWith(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: AppColors.espressoDark,
            ),
          ),
        ],
      ),
    );
  }
}
