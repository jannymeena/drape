import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../models/measurements_draft.dart';
import '../widgets/blueprint_scaffold.dart';
import 'shape_avatar_reveal_screen.dart';
import 'shape_finder_controller.dart';
import 'shape_finder_ui.dart';

/// "We think you're…": the suggested shape, what it's based on, and two
/// runners-up the user can swap in. Confirming leads to the avatar reveal.
class ShapeResultScreen extends ConsumerWidget {
  static const path = '/onboarding/blueprint/shape/result';
  static const name = 'shape_result';

  const ShapeResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finder = ref.watch(shapeFinderProvider);
    final estimate = finder.estimate;
    final caption = BlueprintText.caption(context);
    if (estimate == null) return const SizedBox.shrink();

    final shapes = {for (final s in bodyShapesFor(finder.set)) s.value: s};
    final best = shapes[estimate.best]!;
    final alternatives = [for (final a in estimate.alternatives) ?shapes[a]];

    return ShapeFinderScaffold(
      section: 'Your shape',
      onForward: () => context.pushNamed(ShapeAvatarRevealScreen.name),
      bottom: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ShapeFinderSecondaryButton(
            label: 'Choose a Different Shape',
            onPressed: () => backToShapeGrid(context),
          ),
          const SizedBox(height: 10),
          ShapeFinderPrimaryButton(
            label: 'Yes, That’s Me',
            onPressed: () => context.pushNamed(ShapeAvatarRevealScreen.name),
          ),
        ],
      ),
      children: [
        const ShapeFinderHeading('We think you’re…'),
        const SizedBox(height: 16),
        ShapeFinderCard(
          radius: 28,
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ivoryHigh,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: AppColors.sage,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Best match',
                        style: caption.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.espressoDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 150,
                height: 150,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  bodyShapeFigure(finder.set, best.value),
                  height: 125,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                best.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: AppColors.espressoDark,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                best.description,
                textAlign: TextAlign.center,
                style: BlueprintText.subtitle(context).copyWith(fontSize: 14),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ivoryDim,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    if (finder.source == ShapeSource.measurements)
                      _Basis(
                        Icons.straighten,
                        _measurementsLine(finder),
                        strong: true,
                      ),
                    if (finder.source == ShapeSource.photo)
                      const _Basis(
                        Icons.delete_outline,
                        'Your temporary photo has been securely deleted.',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (alternatives.isNotEmpty) ...[
          const SizedBox(height: 24),
          Row(
            children: [
              Text(
                'ALSO CLOSE',
                style: caption.copyWith(
                  fontSize: 11,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text('Tap to choose', style: caption.copyWith(fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < alternatives.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(
                    child: _Alternative(
                      option: alternatives[i],
                      figure: bodyShapeFigure(
                        finder.set,
                        alternatives[i].value,
                      ),
                      onTap: () => ref
                          .read(shapeFinderProvider.notifier)
                          .promote(alternatives[i].value),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// "Based on your chest 42″, waist 32″ and hips 38″." in the unit the user
  /// entered them in.
  String _measurementsLine(ShapeFinderState finder) {
    String v(MeasurementField f) {
      final cm = finder.cm[f];
      if (cm == null) return '–';
      return finder.imperial ? '${(cm / 2.54).round()}″' : '${cm.round()} cm';
    }

    final chest = finder.set == BodyShapeSet.womens ? 'bust' : 'chest';
    return 'Based on your $chest ${v(MeasurementField.chest)}, '
        'waist ${v(MeasurementField.waist)} and '
        'hips ${v(MeasurementField.hips)}.';
  }
}

class _Basis extends StatelessWidget {
  const _Basis(this.icon, this.text, {this.strong = false});

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.espressoDark),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: strong
                ? BlueprintText.option(
                    context,
                  ).copyWith(fontSize: 13, fontWeight: FontWeight.w600)
                : BlueprintText.optionSupport(context).copyWith(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _Alternative extends StatelessWidget {
  const _Alternative({
    required this.option,
    required this.figure,
    required this.onTap,
  });

  final BodyShapeOption option;

  /// The shape's figure asset ([bodyShapeFigure]).
  final String figure;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ShapeFinderCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SvgPicture.asset(
                    figure,
                    height: 48,
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                  const Spacer(),
                  const ShapeFinderBadgeIcon(
                    Icons.chevron_right,
                    size: 24,
                    background: AppColors.ivoryWarm,
                    color: AppColors.espressoDark,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                option.label,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: AppColors.espressoDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                option.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: BlueprintText.caption(context).copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
