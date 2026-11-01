import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../shop/shop_service.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/option_card.dart';
import 'blueprint_fit_screen.dart';

/// Step 1 of 7 — who we're shopping for, and life stage.
///
/// Merges what used to be two screens (shopping style, age range). Shopping
/// style is required; age range is skippable via its own "Prefer not to say"
/// chip, which sends null.
class BlueprintIdentityScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/identity';
  static const name = 'blueprint_identity';

  const BlueprintIdentityScreen({super.key});

  @override
  ConsumerState<BlueprintIdentityScreen> createState() =>
      _BlueprintIdentityScreenState();
}

class _BlueprintIdentityScreenState
    extends ConsumerState<BlueprintIdentityScreen> {
  // (backend literal, label). Parallel lists would drift; tuples don't.
  // The backend still accepts 'both'; the redesign no longer offers it, so a
  // user who picked it earlier resumes with nothing selected.
  static const _styles = <(String, String)>[
    ('womens', 'Women’s Fashion'),
    ('mens', 'Men’s Fashion'),
    ('prefer_not_to_say', 'Prefer not to say'),
  ];

  /// A null value is the explicit "skip this question" signal the backend
  /// accepts — distinct from "not answered yet" (nothing selected).
  static const _ages = <(String?, String)>[
    ('18-24', '18–24'),
    ('25-34', '25–34'),
    ('35-44', '35–44'),
    ('45-54', '45–54'),
    ('55+', '55+'),
    (null, 'Prefer not to say'),
  ];

  final _ageQuestion = GlobalKey();

  String? _style;
  int? _ageIndex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the saved profile when resuming onboarding.
    final saved = ref.read(onboardingControllerProvider);
    final savedStyle = saved.shoppingStyle;
    if (_styles.any((s) => s.$1 == savedStyle)) _style = savedStyle;
    if (saved.ageRange != null) {
      final i = _ages.indexWhere((a) => a.$1 == saved.ageRange);
      if (i != -1) _ageIndex = i;
    }
  }

  Future<void> _onContinue() async {
    final style = _style;
    if (style == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).setBlueprintIdentity(
            shoppingStyle: style,
            ageRange: _ageIndex == null ? null : _ages[_ageIndex!].$1,
          );
      // Shopping style is saved, so the gender-filtered shop feed is final:
      // warm its cache while the rest of onboarding runs.
      unawaited(ref.read(shopServiceProvider).prefetchFeed());
      if (!mounted) return;
      context.pushNamed(BlueprintFitScreen.name);
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
      step: 1,
      canContinue: _style != null,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'What style do you shop for?',
          subtitle:
              'This helps ZOURA suggest the right products and outfit ideas for you.',
        ),
        const SizedBox(height: 16),
        for (final (value, label) in _styles) ...[
          OptionCard(
            label: label,
            selected: _style == value,
            onTap: () {
              if (_submitting) return;
              final firstAnswer = _style == null;
              setState(() => _style = value);
              if (firstAnswer) revealNextQuestion(_ageQuestion);
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        BlueprintQuestion(
          key: _ageQuestion,
          title: 'What’s your age range?',
          subtitle: 'Helps us fit styles to your life stage',
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          mainAxisExtent: 52,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (var i = 0; i < _ages.length; i++)
              _AgeChip(
                label: _ages[i].$2,
                selected: _ageIndex == i,
                onTap: () {
                  if (_submitting) return;
                  // Tapping the selected chip clears it — the question is
                  // optional, so there has to be a way back to "unanswered".
                  setState(() => _ageIndex = _ageIndex == i ? null : i);
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _AgeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AgeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ivoryHigh : AppColors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.espressoDark : AppColors.taupeSoft,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Center(
          child: Text(
            label,
            style: BlueprintText.option(context).copyWith(fontSize: 14),
          ),
        ),
      ),
    );
  }
}
