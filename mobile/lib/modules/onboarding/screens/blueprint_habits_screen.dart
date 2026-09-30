import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_goals_screen.dart';

/// Step 6 of 7 — how the user feels about getting dressed, how much jewellery
/// they wear, and the price bracket they shop in.
class BlueprintHabitsScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/habits';
  static const name = 'blueprint_habits';

  const BlueprintHabitsScreen({super.key});

  @override
  ConsumerState<BlueprintHabitsScreen> createState() =>
      _BlueprintHabitsScreenState();
}

class _BlueprintHabitsScreenState extends ConsumerState<BlueprintHabitsScreen> {
  // (value, label, supporting copy)
  static const _feelings = <(String, String, String)>[
    (
      'confident',
      'Confident and in control',
      'I know what works for me and enjoy the process.'
    ),
    (
      'necessity',
      'It’s just a necessity',
      'I want to look good but don’t want to spend time on it.'
    ),
    (
      'frustrated',
      'Often frustrated',
      'I struggle to find things that fit or look right.'
    ),
    (
      'exploring',
      'Ready for a change',
      'I want to elevate my style but don’t know where to start.'
    ),
  ];

  static const _accessories = <(String, String, String)>[
    ('none', 'None at all', ''),
    ('minimal', 'Minimal — 1 to 3', ''),
    ('statement', 'Statement pieces', ''),
  ];

  // (value, label, example brands) — the examples are what make an abstract
  // price bracket answerable.
  static const _tiers = <(String, String, String)>[
    ('fast_fashion', 'Accessible / Fast Fashion', 'Zara · H&M · Uniqlo'),
    ('premium', 'Premium brands', 'Theory · Vince · Reformation'),
    ('luxury', 'Designer / Luxury', 'The Row · Khaite · Prada'),
    ('mix', 'A high-low mix', 'Vintage · Boutique · Contemporary'),
  ];

  final _accessoryQuestion = GlobalKey();
  final _tierQuestion = GlobalKey();

  String? _feeling;
  String? _accessory;
  String? _tier;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _feeling = saved.shoppingFeeling;
    _accessory = saved.accessories;
    _tier = saved.brandTier;
  }

  bool get _complete =>
      _feeling != null && _accessory != null && _tier != null;

  Future<void> _onContinue() async {
    if (!_complete || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).setBlueprintHabits(
            shoppingFeeling: _feeling!,
            accessories: _accessory!,
            brandTier: _tier!,
          );
      if (!mounted) return;
      context.pushNamed(BlueprintGoalsScreen.name);
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
      step: 6,
      canContinue: _complete,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'How do you feel about shopping and getting dressed?',
        ),
        const SizedBox(height: 16),
        for (final (value, label, support) in _feelings) ...[
          _RadioRow(
            label: label,
            support: support,
            selected: _feeling == value,
            onTap: () {
              if (_submitting) return;
              final firstAnswer = _feeling == null;
              setState(() => _feeling = value);
              if (firstAnswer) revealNextQuestion(_accessoryQuestion);
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        BlueprintQuestion(
          key: _accessoryQuestion,
          title: 'How do you feel about accessories?',
        ),
        const SizedBox(height: 16),
        for (final (value, label, support) in _accessories) ...[
          _RadioRow(
            label: label,
            support: support,
            selected: _accessory == value,
            onTap: () {
              if (_submitting) return;
              final firstAnswer = _accessory == null;
              setState(() => _accessory = value);
              if (firstAnswer) revealNextQuestion(_tierQuestion);
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        BlueprintQuestion(
          key: _tierQuestion,
          title: 'Which types of brands do you prefer?',
          subtitle: 'This helps us match products to your budget.',
        ),
        const SizedBox(height: 16),
        for (final (value, label, support) in _tiers) ...[
          _RadioRow(
            label: label,
            support: support,
            selected: _tier == value,
            onTap: () {
              if (_submitting) return;
              setState(() => _tier = value);
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

/// A radio option with an optional supporting line under its label.
class _RadioRow extends StatelessWidget {
  final String label;
  final String support;
  final bool selected;
  final VoidCallback onTap;

  const _RadioRow({
    required this.label,
    required this.support,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.ivoryWarm : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color:
                        selected ? AppColors.espresso : AppColors.taupeSoft,
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: selected
                    ? Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: AppColors.espresso,
                          shape: BoxShape.circle,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: BlueprintText.option(context)),
                    if (support.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(support,
                          style: BlueprintText.optionSupport(context)),
                    ],
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
