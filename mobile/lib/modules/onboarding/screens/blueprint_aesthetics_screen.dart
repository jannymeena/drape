import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_chip.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_color_screen.dart';

/// One style card: the backend literal, its label, and the art to show.
typedef _Aesthetic = ({String value, String label, String asset});

/// Step 3 of 8 — "Which styles do you like?", a multi-select card grid, and
/// an optional "Want to get more specific?" card of micro-aesthetic tags
/// (the same tags whatever the card set).
///
/// The card set is gendered: four aesthetics are shared, and two differ per
/// set — men see Rugged and Smart Casual, women see Bohemian and Romantic.
/// Which set to show is driven by the step-1 shopping-style answer;
/// `both` / `prefer_not_to_say` get the women's set as the default, since it's
/// the broader catalogue.
class BlueprintAestheticsScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/aesthetics';
  static const name = 'blueprint_aesthetics';

  const BlueprintAestheticsScreen({super.key});

  @override
  ConsumerState<BlueprintAestheticsScreen> createState() =>
      _BlueprintAestheticsScreenState();
}

class _BlueprintAestheticsScreenState
    extends ConsumerState<BlueprintAestheticsScreen> {
  static const _mens = <_Aesthetic>[
    (value: 'minimalist', label: 'Minimalist', asset: 'male/minimalist'),
    (value: 'rugged', label: 'Rugged', asset: 'male/rugged'),
    (value: 'professional', label: 'Professional', asset: 'male/professional'),
    (value: 'streetwear', label: 'Streetwear', asset: 'male/streetwear'),
    (value: 'smart_casual', label: 'Smart Casual', asset: 'male/smart_casual'),
    (value: 'avant_garde', label: 'Avant-Garde', asset: 'male/avant_garde'),
  ];

  static const _womens = <_Aesthetic>[
    (value: 'minimalist', label: 'Minimalist', asset: 'female/minimalist'),
    (value: 'bohemian', label: 'Bohemian', asset: 'female/bohemian'),
    (
      value: 'professional',
      label: 'Professional',
      asset: 'female/professional',
    ),
    (value: 'streetwear', label: 'Streetwear', asset: 'female/streetwear'),
    (value: 'romantic', label: 'Romantic', asset: 'female/romantic'),
    (value: 'avant_garde', label: 'Avant-Garde', asset: 'female/avant_garde'),
  ];

  /// The "Want to get more specific?" tags, the same for every card set.
  static const _microTags = <({String value, String label})>[
    (value: 'quiet_luxury', label: 'Quiet Luxury'),
    (value: 'french_chic', label: 'French Chic'),
    (value: 'monochrome', label: 'Monochrome'),
    (value: 'coastal_grandmother', label: 'Coastal Grandmother'),
    (value: 'artisanal_folk', label: 'Artisanal Folk'),
    (value: '90s_slouch', label: '90s Slouch'),
  ];

  final _selected = <String>{};
  final _micro = <String>{};

  /// Whether the "Want to get more specific?" card is open: closed at
  /// first, unless tags were picked before.
  late bool _specificsOpen;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final blueprint = ref.read(onboardingControllerProvider).blueprint;
    _selected.addAll(blueprint.styleAesthetics);
    _micro.addAll(blueprint.microAesthetics);
    _specificsOpen = _micro.isNotEmpty;
  }

  bool get _isMens =>
      ref.read(onboardingControllerProvider).shoppingStyle == 'mens';

  List<_Aesthetic> get _cards => _isMens ? _mens : _womens;

  /// The photos' own shape (the men's set is a little taller than wide, the
  /// women's a little wider than tall), so the whole look shows instead of a
  /// cropped, zoomed-in slice.
  double get _photoAspectRatio => _isMens ? 357 / 399 : 360 / 346;

  /// Records the answers and moves straight on; the save runs in the
  /// background, and a failure is retried with the next step's save.
  void _onContinue() {
    if (_selected.isEmpty || _leaving) return;

    // Send in card order rather than tap order so the stored list is stable
    // across sessions.
    final ordered = [
      for (final card in _cards)
        if (_selected.contains(card.value)) card.value,
    ];
    final micro = [
      for (final tag in _microTags)
        if (_micro.contains(tag.value)) tag.value,
    ];
    // Saved in the background; see OnboardingController._save.
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintAesthetics(ordered, micro: micro);
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintColorScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 3,
      canContinue: _selected.isNotEmpty,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'Which styles do you like?',
          subtitle: 'Select all that apply.',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            // Each card is its photo, at the photo's shape, plus the card's
            // inner padding all round.
            const gap = 12.0;
            const inset = _StyleCard.padding;
            final cardWidth = (box.maxWidth - gap) / 2;
            final cardHeight =
                (cardWidth - 2 * inset) / _photoAspectRatio + 2 * inset;
            return GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: gap,
                mainAxisSpacing: gap,
                mainAxisExtent: cardHeight,
              ),
              children: [
                for (final card in _cards)
                  _StyleCard(
                    label: card.label,
                    asset: 'assets/onboarding/styles/${card.asset}.jpg',
                    selected: _selected.contains(card.value),
                    onTap: () {
                      if (_leaving) return;
                      setState(() {
                        if (!_selected.add(card.value)) {
                          _selected.remove(card.value);
                        }
                      });
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _SpecificsCard(
          open: _specificsOpen,
          onToggle: () => setState(() => _specificsOpen = !_specificsOpen),
          tags: [
            for (final tag in _microTags)
              (
                label: tag.label,
                selected: _micro.contains(tag.value),
                onTap: () {
                  if (_leaving) return;
                  setState(() {
                    if (!_micro.add(tag.value)) _micro.remove(tag.value);
                  });
                },
              ),
          ],
        ),
      ],
    );
  }
}

/// "Optional details — Want to get more specific?": a card that opens to
/// micro-aesthetic tags, any number of which can be picked.
class _SpecificsCard extends StatelessWidget {
  const _SpecificsCard({
    required this.open,
    required this.onToggle,
    required this.tags,
  });

  final bool open;
  final VoidCallback onToggle;
  final List<({String label, bool selected, VoidCallback onTap})> tags;

  @override
  Widget build(BuildContext context) {
    final caption = BlueprintText.caption(context);
    return Material(
      color: AppColors.white,
      elevation: 0.5,
      shadowColor: AppColors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              expanded: open,
              button: true,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'OPTIONAL DETAILS',
                              style: caption.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.5,
                                color: AppColors.taupe,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Want to get more specific?',
                              style: BlueprintText.option(context).copyWith(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.ivoryWarm,
                          shape: BoxShape.circle,
                        ),
                        child: AnimatedRotation(
                          turns: open ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: const Icon(
                            Icons.expand_more,
                            size: 20,
                            color: AppColors.espressoDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select micro-aesthetics and fit nuances to refine your '
                      'digital wardrobe capsule.',
                      style: BlueprintText.optionSupport(context).copyWith(
                        fontSize: 12,
                        height: 1.5,
                        color: AppColors.inkSoft,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in tags)
                          BlueprintChip(
                            label: tag.label,
                            selected: tag.selected,
                            onTap: tag.onTap,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StyleCard extends StatelessWidget {
  final String label;
  final String asset;
  final bool selected;
  final VoidCallback onTap;

  const _StyleCard({
    required this.label,
    required this.asset,
    required this.selected,
    required this.onTap,
  });

  /// Room between the card's edge and its photo.
  static const padding = 8.0;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFFDF5EE) : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.espresso : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(padding),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: AppColors.sand,
                  child: Image.asset(asset, fit: BoxFit.cover),
                ),
                // Scrim so the label stays legible over any part of the photo.
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [Colors.black87, Colors.transparent],
                      stops: [0.0, 0.55],
                    ),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    label,
                    style: BlueprintText.option(context).copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Positioned(
                    top: 8,
                    right: 8,
                    child: CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.espresso,
                      child: Icon(
                        Icons.check,
                        size: 15,
                        color: AppColors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
