import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/line_glyph.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';
import '../widgets/pipeda_note.dart';

/// The sub-flow's finale, in the dark atelier palette: the styled avatar,
/// the measurements behind it, and on into the rest of the blueprint.
class ShapeAvatarRevealScreen extends ConsumerWidget {
  static const path = '/onboarding/blueprint/shape/reveal';
  static const name = 'shape_avatar_reveal';

  const ShapeAvatarRevealScreen({super.key});

  static const _background = Color(0xFF1A120D);
  static const _panel = Color(0xFF2A1D15);
  static const _gold = AppColors.goldSoft;
  static const _muted = Color(0xFFB8A99C);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finder = ref.watch(shapeFinderProvider);
    final caption = BlueprintText.caption(context);
    final chips = [
      for (final field in shapeMeasurements)
        if (finder.cm[field] case final cm?)
          (
            finder.imperial ? '${(cm / 2.54).round()}″' : '${cm.round()} cm',
            field == MeasurementField.chest && finder.set == BodyShapeSet.womens
                ? 'bust'
                : field.name,
          ),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left, size: 28),
                  color: _muted,
                  tooltip: 'Go back',
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'ZOURA ATELIER',
                        style: caption.copyWith(
                          fontSize: 11,
                          letterSpacing: 3,
                          fontWeight: FontWeight.w700,
                          color: _gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Meet yourself, styled.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge!
                            .copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Calibrated to your proportions.',
                        style: BlueprintText.subtitle(
                          context,
                        ).copyWith(fontSize: 14, color: _muted),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 320,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            SvgPicture.asset(
                              'assets/onboarding/atelier_avatar.svg',
                              height: 320,
                            ),
                            const Positioned(
                              right: 40,
                              top: 10,
                              child: _Sparkle(18),
                            ),
                            const Positioned(
                              left: 50,
                              top: 70,
                              child: _Sparkle(12),
                            ),
                            const Positioned(
                              right: 56,
                              top: 150,
                              child: _Sparkle(10),
                            ),
                          ],
                        ),
                      ),
                      if (chips.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final (value, label) in chips)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: _panel,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: value,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.white,
                                        ),
                                      ),
                                      TextSpan(text: '  $label'),
                                    ],
                                  ),
                                  style: caption.copyWith(color: _muted),
                                ),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _panel,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.straighten,
                              size: 18,
                              color: _gold,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Add height, inseam, thigh and weight anytime '
                                'in your profile to sharpen your fit.',
                                style: BlueprintText.optionSupport(
                                  context,
                                ).copyWith(fontSize: 12, color: _muted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  children: [
                    SizedBox(
                      height: 56,
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => finishShapeFinder(
                          context,
                          ref,
                          finder.estimate?.best,
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: _gold,
                          foregroundColor: AppColors.espressoDeep,
                          shape: const StadiumBorder(),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Let’s Style You',
                              style: Theme.of(context).textTheme.titleMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.espressoDeep,
                                  ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const PipedaNote(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  const _Sparkle(this.size);

  final double size;

  static const _star = LineGlyphData(24, 24, [
    GlyphStroke.path(
      'M12 0L13.8 9.2L23 12L13.8 14.8L12 24L10.2 14.8L1 12L10.2 9.2L12 0Z',
      width: 0,
      fill: 1,
    ),
  ]);

  @override
  Widget build(BuildContext context) {
    return LineGlyph(
      _star,
      size: Size.square(size),
      color: ShapeAvatarRevealScreen._gold,
    );
  }
}
