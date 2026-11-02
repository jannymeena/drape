import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_analyzing_screen.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';

/// The photo framing check: the shot with shoulder / waist / hip guides, and
/// the option to blur the face before it's analyzed.
class ShapePhotoReviewScreen extends ConsumerWidget {
  static const path = '/onboarding/blueprint/shape/photo/review';
  static const name = 'shape_photo_review';

  const ShapePhotoReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finder = ref.watch(shapeFinderProvider);
    final photo = finder.photo;
    return ShapeFinderScaffold(
      section: 'Framing check',
      children: [
        const ShapeFinderHeading(
          'Check your photo',
          body: 'Make sure your full silhouette is visible from head to toe.',
        ),
        const SizedBox(height: 16),
        if (photo != null)
          _PhotoWithGuides(file: File(photo.path), blurFace: finder.blurFace),
        const SizedBox(height: 16),
        ShapeFinderCard(
          padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
          radius: 16,
          child: Row(
            children: [
              const ShapeFinderBadgeIcon(
                Icons.visibility_off_outlined,
                size: 40,
                background: AppColors.ivoryWarm,
                color: AppColors.espressoDark,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Blur my face',
                      style: BlueprintText.option(
                        context,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Hides facial features during analysis',
                      style: BlueprintText.caption(
                        context,
                      ).copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: finder.blurFace,
                onChanged: ref.read(shapeFinderProvider.notifier).setBlurFace,
                activeTrackColor: AppColors.espresso,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const ShapeFinderResidencyNote(
          text:
              'Processed securely. Deleted as soon as your shape is estimated.',
        ),
        const SizedBox(height: 20),
        Text(
          'Looks good?',
          textAlign: TextAlign.center,
          style: BlueprintText.option(
            context,
          ).copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        ShapeFinderPrimaryButton(
          label: 'Use This Photo',
          trailing: Icons.arrow_forward,
          onPressed: photo == null
              ? null
              : () => context.pushReplacementNamed(ShapeAnalyzingScreen.name),
        ),
        const SizedBox(height: 4),
        ShapeFinderLink(
          label: 'Retake photo',
          leading: Icons.photo_camera_outlined,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// The photo at 3:4 with dashed guide lines where shoulders, waist and hips
/// should sit, and — when [blurFace] — a frosted disc over where a standing
/// person's head is.
///
/// The disc's position is a fixed guess (top centre), not a detected face:
/// detection comes with the shape analysis itself.
class _PhotoWithGuides extends StatelessWidget {
  const _PhotoWithGuides({required this.file, required this.blurFace});

  final File file;
  final bool blurFace;

  static const _guides = [(0.32, 'Shoulders'), (0.46, 'Waist'), (0.58, 'Hips')];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: LayoutBuilder(
          builder: (context, box) {
            final disc = box.maxWidth * 0.3;
            return Stack(
              fit: StackFit.expand,
              children: [
                Image.file(file, fit: BoxFit.cover),
                for (final (y, label) in _guides)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: box.maxHeight * y - 12,
                    height: 24,
                    child: _GuideLine(label),
                  ),
                if (blurFace)
                  Positioned(
                    top: box.maxHeight * 0.05,
                    left: (box.maxWidth - disc) / 2,
                    width: disc,
                    height: disc,
                    child: ClipOval(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: Container(
                          color: AppColors.white.withValues(alpha: 0.2),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 12,
                  top: 12,
                  child: _Chip(
                    leading: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                    ),
                    label: 'FRAMING GUIDE',
                  ),
                ),
                if (blurFace)
                  const Positioned(
                    right: 12,
                    top: 12,
                    child: _Chip(
                      leading: Icon(
                        Icons.lock,
                        size: 12,
                        color: AppColors.espressoDark,
                      ),
                      label: 'Face blurred',
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GuideLine extends StatelessWidget {
  const _GuideLine(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(child: CustomPaint(painter: _DashedLinePainter())),
        _Chip(label: label),
      ],
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, this.leading});

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
