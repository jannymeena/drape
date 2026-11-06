import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/line_glyph.dart';
import '../widgets/privacy_sheet.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';
import 'shape_measure_screen.dart';
import 'shape_photo_review_screen.dart';
import '../widgets/pipeda_note.dart';

/// The photo path's start: how the photo is handled, tips for a usable shot,
/// consent, then camera or library.
class ShapePhotoTipsScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/shape/photo';
  static const name = 'shape_photo_tips';

  const ShapePhotoTipsScreen({super.key});

  @override
  ConsumerState<ShapePhotoTipsScreen> createState() =>
      _ShapePhotoTipsScreenState();
}

class _ShapePhotoTipsScreenState extends ConsumerState<ShapePhotoTipsScreen> {
  bool _consent = false;
  bool _picking = false;

  Future<void> _pick(ImageSource source) async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final photo = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      ref.read(shapeFinderProvider.notifier).setPhoto(photo);
      await context.pushNamed(ShapePhotoReviewScreen.name);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    final ready = _consent && !_picking;
    return ShapeFinderScaffold(
      section: 'Photo estimate',
      children: [
        const ShapeFinderHeading(
          'Upload a full-body photo',
          body:
              'We estimate your silhouette proportions from a single photo. '
              'Prefer a tape measure? You can enter measurements instead.',
        ),
        const SizedBox(height: 20),
        ShapeFinderCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const ShapeFinderBadgeIcon(Icons.verified_user_outlined),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How we handle your photo',
                          style: BlueprintText.option(
                            context,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          'Confidential, ephemeral & secure',
                          style: caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              for (final line in const [
                'Used solely to estimate your contour and drape.',
                'Deleted as soon as your shape is estimated — never stored.',
                'Never sold, shared, or used to train public AI models.',
                'Read on your phone — never uploaded.',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check, size: 16, color: AppColors.sage),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          line,
                          style: BlueprintText.optionSupport(
                            context,
                          ).copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShapeFinderCard(
          color: AppColors.ivoryDim,
          shadow: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PHOTO TIPS FOR ACCURACY',
                style: caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 100,
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        LineGlyph(
                          bodyShapesFor(BodyShapeSet.neutral).first.glyph,
                          size: const Size(70, 98),
                          highlight: true,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'FITTED PROFILE',
                          style: caption.copyWith(
                            fontSize: 8,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final tip in const [
                          'Stand straight, full length, facing the camera.',
                          'Wear fitted clothes or activewear.',
                          'Plain background with soft, natural light.',
                          'Keep your arms a little away from your body.',
                          'Your face can stay out of frame if you prefer.',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 6,
                                    right: 8,
                                  ),
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: AppColors.taupe,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    tip,
                                    style: BlueprintText.optionSupport(
                                      context,
                                    ).copyWith(fontSize: 12.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShapeFinderCard(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          radius: 16,
          child: Row(
            children: [
              Checkbox(
                value: _consent,
                onChanged: (v) => setState(() => _consent = v ?? false),
                activeColor: AppColors.espressoDark,
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text:
                        'I agree Zoura can analyze this photo to estimate my '
                        'body shape and silhouette. Read our ',
                    children: [
                      TextSpan(
                        text: 'Privacy Policy',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                          color: AppColors.espressoDark,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => showPrivacySheet(context),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                  style: BlueprintText.optionSupport(
                    context,
                  ).copyWith(fontSize: 13, color: AppColors.ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ShapeFinderPrimaryButton(
          label: 'Take Photo',
          leading: Icons.photo_camera_outlined,
          onPressed: ready ? () => _pick(ImageSource.camera) : null,
        ),
        const SizedBox(height: 10),
        ShapeFinderSecondaryButton(
          label: 'Choose From Library',
          leading: Icons.photo_library_outlined,
          onPressed: ready ? () => _pick(ImageSource.gallery) : null,
        ),
        const SizedBox(height: 8),
        ShapeFinderLink(
          label: 'Enter manual measurements instead',
          leading: Icons.straighten,
          onPressed: () =>
              context.pushReplacementNamed(ShapeMeasureScreen.name),
        ),
        const SizedBox(height: 8),
        const PipedaNote(),
      ],
    );
  }
}
