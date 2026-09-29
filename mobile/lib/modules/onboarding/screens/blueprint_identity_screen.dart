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
  static const _styles = <(String, String, IconData)>[
    ('womens', 'Women’s Fashion', Icons.dry_cleaning_outlined),
    ('mens', 'Men’s Fashion', Icons.checkroom),
    ('both', 'Both / All Styles', Icons.style_outlined),
    ('prefer_not_to_say', 'Prefer not to say', Icons.help_outline),
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

  String? _style;
  int? _ageIndex;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // Prefill from the saved profile when resuming onboarding.
    final saved = ref.read(onboardingControllerProvider);
    _style = saved.shoppingStyle;
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
        for (final (value, label, icon) in _styles) ...[
          OptionCard(
            label: label,
            icon: icon,
            selected: _style == value,
            onTap: () {
              if (_submitting) return;
              setState(() => _style = value);
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 20),
        const BlueprintQuestion(
          title: 'What’s your age range?',
          subtitle: 'Helps us fit styles to your life stage.',
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
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
      color: selected ? AppColors.ivoryWarm : AppColors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(label, style: BlueprintText.option(context)),
        ),
      ),
    );
  }
}
