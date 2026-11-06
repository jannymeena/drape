import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../onboarding_controller.dart';
import '../shape_finder/shape_finder_controller.dart';
import '../shape_finder/shape_intro_screen.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_aesthetics_screen.dart';

/// Step 2 of 8 — body shape and how clothes should sit.
///
/// One layout for every step 1 answer: a grid of shape cards ending in a
/// "Not sure?" card, then two fit questions as three-way segmented controls.
/// What varies is the content, per [_Copy]: the shape set and its drawings
/// (named shapes for women's, "builds" for men's, silhouette descriptions for
/// "prefer not to say"), the wording, and — gender-neutral only — a
/// data-residency note. Every variant stores the same backend values.
/// "Not sure?" opens the shape finder (measurements or a photo), which
/// finishes this step itself.
///
/// Fit is three stops, never a free range: the backend stores a literal
/// (`slim`/`regular`/`loose`), so a continuous control would only invite a
/// precision the data model doesn't have.
class BlueprintFitScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/fit';
  static const name = 'blueprint_fit';

  const BlueprintFitScreen({super.key});

  @override
  ConsumerState<BlueprintFitScreen> createState() => _BlueprintFitScreenState();
}

/// One fit stop: the backend literal and its label on the control.
typedef _Stop = (String value, String label);

/// The wording and sizing that differ between the step 2 variants.
class _Copy {
  const _Copy({
    required this.title,
    required this.fitTitle,
    required this.topHeading,
    required this.bottomHeading,
    required this.tops,
    required this.bottoms,
  });

  final String title;
  final String fitTitle;
  final String topHeading;
  final String bottomHeading;
  final List<_Stop> tops;
  final List<_Stop> bottoms;
}

const _copy = {
  BodyShapeSet.womens: _Copy(
    title: 'Which body shape feels closest?',
    fitTitle: 'How do you prefer your clothes to fit?',
    topHeading: 'Preferred top fit',
    bottomHeading: 'Preferred bottom fit',
    tops: [
      ('slim', 'Slim fitted'),
      ('regular', 'Regular fit'),
      ('loose', 'Loose'),
    ],
    bottoms: [
      ('skinny', 'Skinny fit'),
      ('relaxed', 'Relaxed fit'),
      ('baggy', 'Baggy'),
    ],
  ),
  BodyShapeSet.mens: _Copy(
    title: 'Which build feels closest?',
    fitTitle: 'Fit preferences',
    topHeading: 'Preferred top fit',
    bottomHeading: 'Preferred trouser fit',
    tops: [('slim', 'Slim'), ('regular', 'Regular'), ('loose', 'Relaxed')],
    bottoms: [
      ('skinny', 'Slim'),
      ('relaxed', 'Straight'),
      ('baggy', 'Relaxed'),
    ],
  ),
  BodyShapeSet.neutral: _Copy(
    title: 'Which shape feels closest?',
    fitTitle: 'How do you prefer clothes to fit?',
    topHeading: 'Top fit',
    bottomHeading: 'Bottom fit',
    tops: [('slim', 'Fitted'), ('regular', 'Regular'), ('loose', 'Oversized')],
    bottoms: [('skinny', 'Slim'), ('relaxed', 'Straight'), ('baggy', 'Wide')],
  ),
};

class _BlueprintFitScreenState extends ConsumerState<BlueprintFitScreen> {
  final _fitQuestion = GlobalKey();

  late final BodyShapeSet _set;
  late final _Copy _c;
  late final List<BodyShapeOption> _shapes;

  String? _shape;
  // Default both fit questions to the middle stop: it's the most common answer
  // and means the user only has to touch one they actually disagree with.
  int _topsIndex = 1;
  int _bottomsIndex = 1;
  bool _leaving = false;

  bool get _answered => _shape != null;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingControllerProvider);
    final set = _set = bodyShapeSetFor(state.shoppingStyle);
    _c = _copy[set]!;
    _shapes = bodyShapesFor(set);
    final saved = state.blueprint;
    // A shape from another set (step 1 changed since) isn't on screen, so
    // leave the question unanswered rather than select something invisible.
    if (_shapes.any((s) => s.value == saved.bodyShape)) {
      _shape = saved.bodyShape;
    }
    final t = _c.tops.indexWhere((e) => e.$1 == saved.fitTops);
    if (t != -1) _topsIndex = t;
    final b = _c.bottoms.indexWhere((e) => e.$1 == saved.fitBottoms);
    if (b != -1) _bottomsIndex = b;
  }

  void _select(String value) {
    if (_leaving) return;
    final firstAnswer = !_answered;
    setState(() => _shape = value);
    if (firstAnswer) revealNextQuestion(_fitQuestion);
  }

  /// "Not sure?" — find the shape from measurements or a photo. The sub-flow
  /// finishes step 2 itself, so it takes this step's fit answers along.
  void _findShape() {
    if (_leaving) return;
    ref
        .read(shapeFinderProvider.notifier)
        .start(
          set: _set,
          fitTops: _c.tops[_topsIndex].$1,
          fitBottoms: _c.bottoms[_bottomsIndex].$1,
          saved: ref.read(onboardingControllerProvider).measurements.values,
        );
    context.pushNamed(ShapeIntroScreen.name);
  }

  /// Records the answers and moves straight on; the save runs in the
  /// background, and a failure is retried with the next step's save.
  void _onContinue() {
    if (!_answered || _leaving) return;

    // Saved in the background; see OnboardingController._save.
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintFit(
          bodyShape: _shape,
          fitTops: _c.tops[_topsIndex].$1,
          fitBottoms: _c.bottoms[_bottomsIndex].$1,
        );
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintAestheticsScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 2,
      canContinue: _answered,
      onContinue: _onContinue,
      children: [
        BlueprintQuestion(
          title: _c.title,
          subtitle:
              'Just a quick guess. You can fine-tune it with measurements later.',
        ),
        const SizedBox(height: 20),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 196,
          // The cards' shadows would be clipped at the grid's edge.
          clipBehavior: Clip.none,
          children: [
            for (final s in _shapes)
              _ShapeCard(
                selected: _shape == s.value,
                onTap: () => _select(s.value),
                art: SizedBox.expand(
                  child: SvgPicture.asset(
                    bodyShapeFigure(_set, s.value),
                    fit: BoxFit.contain,
                    excludeFromSemantics: true,
                  ),
                ),
                label: s.label,
                description: s.description,
              ),
            _ShapeCard(
              selected: false,
              onTap: _findShape,
              tinted: true,
              art: const _NotSureArt(),
              label: 'Not sure?',
              description: 'Help me figure it out',
            ),
          ],
        ),
        const SizedBox(height: 32),
        BlueprintQuestion(key: _fitQuestion, title: _c.fitTitle),
        const SizedBox(height: 16),
        _SegmentedFit(
          heading: _c.topHeading,
          stops: _c.tops,
          index: _topsIndex,
          onChanged: (i) => setState(() => _topsIndex = i),
        ),
        const SizedBox(height: 16),
        _SegmentedFit(
          heading: _c.bottomHeading,
          stops: _c.bottoms,
          index: _bottomsIndex,
          onChanged: (i) => setState(() => _bottomsIndex = i),
        ),
      ],
    );
  }
}

const _cardShadow = BoxShadow(
  color: Color(0x0F2A1810),
  blurRadius: 24,
  spreadRadius: -4,
  offset: Offset(0, 4),
);

/// A borderless card on a soft shadow: art over a centred name and
/// description. Selected gets an espresso ring and a faint fill. [tinted] is
/// the "Not sure?" card, set apart in grey.
class _ShapeCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final Widget art;
  final String label;
  final String description;
  final bool tinted;

  const _ShapeCard({
    required this.selected,
    required this.onTap,
    required this.art,
    required this.label,
    required this.description,
    this.tinted = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.ivoryDim
              : tinted
              ? AppColors.ivoryHigh
              : AppColors.white,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.espresso : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [_cardShadow],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Expanded(child: Center(child: art)),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: BlueprintText.option(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.espressoDark,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: BlueprintText.optionSupport(
                      context,
                    ).copyWith(fontSize: 12, height: 1.3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Not sure?" card's art: a tape measure in a circle, where the shapes
/// have a figure.
class _NotSureArt extends StatelessWidget {
  const _NotSureArt();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.sand,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.straighten,
        size: 30,
        color: AppColors.espressoDark,
      ),
    );
  }
}

/// A fit question in a card: a heading over a sliding segmented control.
class _SegmentedFit extends StatelessWidget {
  final String heading;
  final List<_Stop> stops;
  final int index;
  final ValueChanged<int> onChanged;

  const _SegmentedFit({
    required this.heading,
    required this.stops,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [_cardShadow],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              heading,
              style: BlueprintText.caption(context).copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.espressoDark,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _SlidingSegments(
            semanticLabel: heading,
            labels: [for (final s in stops) s.$2],
            index: index,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

/// A pill track whose white thumb slides to the chosen option. Tap an option,
/// or drag along the track and the thumb follows, snapping to the nearest one.
class _SlidingSegments extends StatelessWidget {
  final String semanticLabel;
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  const _SlidingSegments({
    required this.semanticLabel,
    required this.labels,
    required this.index,
    required this.onChanged,
  });

  static const _inset = 4.0;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return LayoutBuilder(
      builder: (context, constraints) {
        final segment = (constraints.maxWidth - _inset * 2) / n;

        void pick(double dx) {
          final i = ((dx - _inset) / segment).floor().clamp(0, n - 1);
          if (i != index) onChanged(i);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) => pick(d.localPosition.dx),
          onHorizontalDragStart: (d) => pick(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => pick(d.localPosition.dx),
          child: Container(
            height: 40,
            padding: const EdgeInsets.all(_inset),
            decoration: BoxDecoration(
              color: AppColors.ivoryWarm,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  left: segment * index,
                  top: 0,
                  bottom: 0,
                  width: segment,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(999),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x14000000),
                          blurRadius: 3,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < n; i++)
                      Expanded(
                        child: Semantics(
                          label: '$semanticLabel: ${labels[i]}',
                          selected: i == index,
                          button: true,
                          onTap: () => onChanged(i),
                          excludeSemantics: true,
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: BlueprintText.caption(context).copyWith(
                                color: i == index
                                    ? AppColors.espressoDark
                                    : AppColors.inkSoft,
                                fontWeight: i == index
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                              child: Text(
                                labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
