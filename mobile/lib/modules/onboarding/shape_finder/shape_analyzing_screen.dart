import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/line_glyph.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';
import 'shape_photo_frame.dart';
import 'shape_photo_error_screen.dart';
import 'shape_result_screen.dart';
import '../widgets/pipeda_note.dart';

/// While the photo is analyzed: the framed shot (face blur and guide lines
/// drawn in), greyed, with a scan passing over an outline. Hands over to the result, or to the error screen.
class ShapeAnalyzingScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/shape/photo/analyzing';
  static const name = 'shape_analyzing';

  const ShapeAnalyzingScreen({super.key});

  @override
  ConsumerState<ShapeAnalyzingScreen> createState() =>
      _ShapeAnalyzingScreenState();
}

class _ShapeAnalyzingScreenState extends ConsumerState<ShapeAnalyzingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
  }

  Future<void> _analyze() async {
    String next;
    try {
      await ref.read(shapeFinderProvider.notifier).estimateFromPhoto();
      next = ShapeResultScreen.name;
    } on PhotoUnreadableException {
      next = ShapePhotoErrorScreen.name;
    }
    // Cancelled meanwhile: the user is already back on the shape grid.
    if (!mounted) return;
    context.pushReplacementNamed(next);
  }

  @override
  void dispose() {
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final finder = ref.watch(shapeFinderProvider);
    final photo = finder.photo;
    final caption = BlueprintText.caption(context);
    return ShapeFinderScaffold(
      section: 'Analyzing outline',
      onBack: () => backToShapeGrid(context),
      children: [
        if (photo != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(30),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x142A1810),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: ShapePhotoFrame(
                file: File(photo.path),
                photoSize: finder.photoSize,
                maxHeight: 340,
                greyscale: true,
                overlays: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: LineGlyph(
                      bodyShapesFor(BodyShapeSet.neutral).first.glyph,
                      size: Size.infinite,
                      highlight: true,
                      color: AppColors.espressoDark,
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _scan,
                    builder: (context, _) => Align(
                      alignment: Alignment(0, _scan.value * 2.4 - 1.2),
                      child: const SizedBox(
                        height: 60,
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0x00EBC07D),
                                Color(0x66EBC07D),
                                Color(0x00EBC07D),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
                badges: [
                  Positioned(
                    left: 10,
                    bottom: 10,
                    child: ShapePhotoChip(
                      leading: Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                      label: 'READING YOUR OUTLINE',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 18),
        AnimatedBuilder(
          animation: _scan,
          builder: (context, _) {
            final active = (_scan.value * 3).floor() % 3;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < 3; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == active
                          ? AppColors.espressoDark
                          : AppColors.taupeSoft,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const ShapeFinderHeading(
          'Almost there…',
          body: 'Working out your body shape…',
          center: true,
        ),
        const SizedBox(height: 24),
        ShapeFinderCard(
          color: AppColors.ivoryDim,
          shadow: false,
          child: Column(
            children: [
              const Icon(Icons.lock, size: 18, color: AppColors.sage),
              const SizedBox(height: 6),
              Text(
                'Your photo is deleted as soon as we finish.',
                textAlign: TextAlign.center,
                style: BlueprintText.optionSupport(
                  context,
                ).copyWith(fontSize: 13),
              ),
              Text(
                'No copies saved.',
                textAlign: TextAlign.center,
                style: caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ShapeFinderLink(
          label: 'Cancel and pick manually',
          trailing: Icons.chevron_right,
          onPressed: () => backToShapeGrid(context),
        ),
        const SizedBox(height: 8),
        const PipedaNote(),
      ],
    );
  }
}
