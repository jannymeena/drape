import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../onboarding_controller.dart';
import '../widgets/blueprint_choice_card.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_reveal_screen.dart';

/// Step 8 of 8 — how the user wants to feel about their style in three
/// months, and what matters most right now (the style goals that drive
/// starter-wardrobe matching and outfit generation). Both pick-any, at least
/// one each.
class BlueprintGoalsScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/goals';
  static const name = 'blueprint_goals';

  const BlueprintGoalsScreen({super.key});

  @override
  ConsumerState<BlueprintGoalsScreen> createState() =>
      _BlueprintGoalsScreenState();
}

class _BlueprintGoalsScreenState extends ConsumerState<BlueprintGoalsScreen> {
  static const _feelings = <(String, String)>[
    ('confident_anywhere', 'Confident wherever I go'),
    ('found_my_look', 'Like I’ve finally found my look'),
    ('excited_not_stressed', 'Excited to get dressed, not stressed'),
    ('proud_no_second_guessing', 'Proud to show up without second-guessing'),
  ];

  // The backend `StyleGoal` literals.
  static const _goals = <(String, String)>[
    ('time_saving', 'Spend less time choosing outfits'),
    ('polished', 'Look more polished & put-together'),
    ('maximize_wardrobe', 'Make the most of clothes I already own'),
    ('discover_style', 'Discover my personal style'),
    ('confidence', 'Feel more confident in what I wear'),
    ('reduce_clutter', 'Reduce closet clutter & decision fatigue'),
  ];

  final _selectedFeelings = <String>{};
  final _selectedGoals = <String>{};
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider);
    _selectedFeelings.addAll(saved.blueprint.threeMonthFeelings);
    _selectedGoals.addAll(saved.styleGoals);
  }

  bool get _complete =>
      _selectedFeelings.isNotEmpty && _selectedGoals.isNotEmpty;

  void _toggle(Set<String> set, String value) {
    if (_leaving) return;
    setState(() {
      if (!set.add(value)) set.remove(value);
    });
  }

  /// Records the answers and moves straight on; the save runs in the
  /// background, and a failure is retried with the next step's save.
  void _onContinue() {
    if (!_complete || _leaving) return;
    // In list order rather than tap order.
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintGoals(
          feelings: [
            for (final f in _feelings)
              if (_selectedFeelings.contains(f.$1)) f.$1,
          ],
          goals: [
            for (final g in _goals)
              if (_selectedGoals.contains(g.$1)) g.$1,
          ],
        );
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintRevealScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 8,
      buttonLabel: 'See My Style Blueprint',
      buttonIcon: Icons.auto_awesome,
      canContinue: _complete,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'In three months, how do you want to feel about your style?',
          subtitle: 'Pick as many as you like.',
        ),
        const SizedBox(height: 20),
        for (final (value, label) in _feelings) ...[
          BlueprintChoiceCard(
            control: ChoiceControl.checkbox,
            label: label,
            selected: _selectedFeelings.contains(value),
            onTap: () => _toggle(_selectedFeelings, value),
          ),
          if (value != _feelings.last.$1) const SizedBox(height: 12),
        ],
        const SizedBox(height: 28),
        const BlueprintSubQuestion(
          'What matters most to you right now?',
          note: 'Pick as many as you like. This shapes how Zoura styles you.',
          italic: false,
          size: 20,
        ),
        const SizedBox(height: 16),
        for (final (value, label) in _goals) ...[
          BlueprintChoiceCard(
            control: ChoiceControl.checkbox,
            label: label,
            selected: _selectedGoals.contains(value),
            onTap: () => _toggle(_selectedGoals, value),
          ),
          if (value != _goals.last.$1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
