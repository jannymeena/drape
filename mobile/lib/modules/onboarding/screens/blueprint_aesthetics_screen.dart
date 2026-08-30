import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_color_screen.dart';

/// One style card: the backend literal, its label, and the art to show.
typedef _Aesthetic = ({String value, String label, String asset});

/// Step 3 of 7 — "Which styles do you like?", a multi-select card grid.
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
    (value: 'professional', label: 'Professional', asset: 'female/professional'),
    (value: 'streetwear', label: 'Streetwear', asset: 'female/streetwear'),
    (value: 'romantic', label: 'Romantic', asset: 'female/romantic'),
    (value: 'avant_garde', label: 'Avant-Garde', asset: 'female/avant_garde'),
  ];

  final _selected = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(
      ref.read(onboardingControllerProvider).blueprint.styleAesthetics,
    );
  }

  List<_Aesthetic> get _cards {
    final style = ref.read(onboardingControllerProvider).shoppingStyle;
    return style == 'mens' ? _mens : _womens;
  }

  Future<void> _onContinue() async {
    if (_selected.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      // Send in card order rather than tap order so the stored list is stable
      // across sessions.
      final ordered = [
        for (final card in _cards)
          if (_selected.contains(card.value)) card.value,
      ];
      await ref
          .read(onboardingControllerProvider.notifier)
          .setBlueprintAesthetics(ordered);
      if (!mounted) return;
      context.pushNamed(BlueprintColorScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 3,
      canContinue: _selected.isNotEmpty,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'Which styles do you like?',
          subtitle: 'Select all that apply.',
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3 / 4,
          children: [
            for (final card in _cards)
              _StyleCard(
                label: card.label,
                asset: 'assets/onboarding/styles/${card.asset}.jpg',
                selected: _selected.contains(card.value),
                onTap: () {
                  if (_submitting) return;
                  setState(() {
                    if (!_selected.add(card.value)) {
                      _selected.remove(card.value);
                    }
                  });
                },
              ),
          ],
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.sand,
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
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(asset, fit: BoxFit.cover),
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
                  child: Icon(Icons.check, size: 15, color: AppColors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
