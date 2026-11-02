import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_finder_ui.dart';
import 'shape_measure_screen.dart';

/// The photo couldn't be read. Offers another photo, measurements, or picking
/// a shape by hand.
class ShapePhotoErrorScreen extends StatelessWidget {
  static const path = '/onboarding/blueprint/shape/photo/error';
  static const name = 'shape_photo_error';

  const ShapePhotoErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    return ShapeFinderScaffold(
      section: 'Photo estimate',
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: AppColors.ivoryHigh,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Container(
              width: 52,
              height: 52,
              decoration: const BoxDecoration(
                color: Color(0xFFFFDEAD),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_rounded,
                size: 28,
                color: AppColors.goldDark,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const ShapeFinderHeading(
          'We couldn’t see your full body.',
          body: 'Try again in better light with your whole body in frame.',
          center: true,
        ),
        const SizedBox(height: 20),
        ShapeFinderCard(
          color: AppColors.ivoryDim,
          shadow: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Example(
                ok: false,
                label: 'Cropped',
                verdict: 'Detected',
                figure: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: AppColors.taupeSoft,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      width: 20,
                      height: 20,
                      color: AppColors.taupeSoft,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward, color: AppColors.taupeSoft),
              _Example(
                ok: true,
                label: 'Full fit',
                verdict: 'Ideal',
                figure: const Icon(
                  Icons.accessibility_new,
                  size: 44,
                  color: AppColors.sage,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ShapeFinderCard(
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'COMMON CAUSES',
                  style: caption.copyWith(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (final (icon, text) in const [
                (
                  Icons.crop_free,
                  'Feet or head were cropped out of the frame.',
                ),
                (
                  Icons.wb_twilight,
                  'Lighting was too dim to make out your outline.',
                ),
                (
                  Icons.checkroom,
                  'Loose or oversized layers hid your silhouette.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      ShapeFinderBadgeIcon(
                        icon,
                        size: 28,
                        background: AppColors.ivoryWarm,
                        color: AppColors.espressoDark,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: BlueprintText.optionSupport(
                            context,
                          ).copyWith(fontSize: 13, color: AppColors.ink),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                decoration: const BoxDecoration(
                  color: AppColors.ivoryDim,
                  borderRadius: BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      size: 18,
                      color: AppColors.sage,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your photo has already been deleted.',
                        style: caption.copyWith(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        ShapeFinderPrimaryButton(
          label: 'Try Again',
          leading: Icons.photo_camera_outlined,
          // Back to the photo tips, under this screen.
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(height: 10),
        ShapeFinderSecondaryButton(
          label: 'Enter Measurements',
          leading: Icons.straighten,
          onPressed: () =>
              context.pushReplacementNamed(ShapeMeasureScreen.name),
        ),
        const SizedBox(height: 4),
        ShapeFinderLink(
          label: 'I’ll pick my shape myself',
          trailing: Icons.chevron_right,
          onPressed: () => backToShapeGrid(context),
        ),
      ],
    );
  }
}

class _Example extends StatelessWidget {
  const _Example({
    required this.ok,
    required this.label,
    required this.verdict,
    required this.figure,
  });

  final bool ok;
  final String label;
  final String verdict;
  final Widget figure;

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    return Column(
      children: [
        Container(
          width: 64,
          height: 80,
          padding: const EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: ok ? AppColors.sageDim : AppColors.ivoryHigh,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Expanded(child: figure),
              Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  label,
                  style: caption.copyWith(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              ok ? Icons.check : Icons.close,
              size: 14,
              color: ok ? AppColors.sage : AppColors.error,
            ),
            const SizedBox(width: 4),
            Text(
              verdict,
              style: caption.copyWith(
                fontSize: 12,
                color: ok ? AppColors.sage : AppColors.error,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
