import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/option_card.dart';
import 'blueprint_reveal_screen.dart';

/// Step 7 of 7 — the three-month aspiration, plus the style goals that drive
/// starter-wardrobe matching and outfit generation.
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
  static const _goals = <(String, String, IconData)>[
    ('time_saving', 'Spend less time choosing outfits', Icons.schedule),
    ('polished', 'Look more polished and put-together', Icons.auto_awesome),
    (
      'maximize_wardrobe',
      'Make the most of the clothes I already own',
      Icons.inventory_2_outlined
    ),
    ('discover_style', 'Discover my personal style', Icons.explore_outlined),
    ('confidence', 'Feel more confident in what I wear', Icons.favorite_border),
    (
      'reduce_clutter',
      'Reduce closet clutter and decision fatigue',
      Icons.delete_outline
    ),
  ];

  final _goalsQuestion = GlobalKey();

  String? _feeling;
  final _selectedGoals = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider);
    _feeling = saved.blueprint.threeMonthFeeling;
    _selectedGoals.addAll(saved.styleGoals);
  }

  bool get _complete => _feeling != null && _selectedGoals.isNotEmpty;

  Future<void> _onContinue() async {
    if (!_complete || _submitting) return;

    setState(() => _submitting = true);
    try {
      final ordered = [
        for (final g in _goals)
          if (_selectedGoals.contains(g.$1)) g.$1,
      ];
      await ref.read(onboardingControllerProvider.notifier).setBlueprintGoals(
            threeMonthFeeling: _feeling!,
            goals: ordered,
          );
      if (!mounted) return;
      context.pushNamed(BlueprintRevealScreen.name);
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
      step: 7,
      buttonLabel: 'See My Style Blueprint',
      canContinue: _complete,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'In three months, how do you want to feel about your style?',
        ),
        const SizedBox(height: 16),
        for (final (value, label) in _feelings) ...[
          OptionCard(
            label: label,
            selected: _feeling == value,
            onTap: () {
              if (_submitting) return;
              final firstAnswer = _feeling == null;
              setState(() => _feeling = value);
              if (firstAnswer) revealNextQuestion(_goalsQuestion);
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 16),
        BlueprintQuestion(
          key: _goalsQuestion,
          title: 'What matters most to you right now?',
          subtitle: 'Pick as many as you like — this shapes how ZOURA styles you.',
        ),
        const SizedBox(height: 16),
        for (final (value, label, icon) in _goals) ...[
          OptionCard(
            label: label,
            icon: icon,
            selector: OptionSelector.checkbox,
            selected: _selectedGoals.contains(value),
            onTap: () {
              if (_submitting) return;
              setState(() {
                if (!_selectedGoals.add(value)) _selectedGoals.remove(value);
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        const SizedBox(height: 4),
        Center(
          child: Text(
            _selectedGoals.isEmpty
                ? 'Select at least one'
                : '${_selectedGoals.length} selected',
            style: BlueprintText.caption(context).copyWith(
              letterSpacing: 1.4,
              color: AppColors.taupe,
            ),
          ),
        ),
      ],
    );
  }
}
