import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_analyzing_screen.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';
import 'shape_photo_frame.dart';

/// The photo framing check: the shot with shoulder / waist / hip guides, and
/// the option to blur the face before it's analyzed.
class ShapePhotoReviewScreen extends ConsumerWidget {
  static const path = '/onboarding/blueprint/shape/photo/review';
  static const name = 'shape_photo_review';

  const ShapePhotoReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finder = ref.watch(shapeFinderProvider);
    final edit = ref.read(shapeFinderProvider.notifier);
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
          ShapePhotoFrame(
            file: File(photo.path),
            photoSize: finder.photoSize,
            guides: finder.guides,
            faceBlur: finder.blurFace ? finder.faceBlur : null,
            onNudgeGuide: edit.nudgeGuide,
            onMoveFaceBlur: edit.moveFaceBlur,
            onGrowFaceBlur: edit.growFaceBlur,
            onScaleFaceBlur: edit.scaleFaceBlur,
            badges: [
              const Positioned(
                left: 12,
                top: 12,
                child: ShapePhotoChip(leading: _Dot(), label: 'FRAMING GUIDE'),
              ),
              if (finder.blurFace)
                const Positioned(
                  right: 12,
                  top: 12,
                  child: ShapePhotoChip(
                    leading: Icon(
                      Icons.lock,
                      size: 12,
                      color: AppColors.espressoDark,
                    ),
                    label: 'Face blurred',
                  ),
                ),
            ],
          ),
        const SizedBox(height: 12),
        _Hint(
          Icons.unfold_more,
          'Drag the Shoulders, Waist and Hips lines to line up with your body.',
        ),
        if (finder.blurFace)
          _Hint(
            Icons.blur_on,
            'Drag the circle over your face. Pinch it, or pull its handle, '
            'to resize.',
          ),
        const SizedBox(height: 12),
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
                onChanged: edit.setBlurFace,
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

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: AppColors.sage,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.icon, this.text);

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.espresso),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: BlueprintText.optionSupport(
                context,
              ).copyWith(fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}
