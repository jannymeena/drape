import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../onboarding_controller.dart';
import '../widgets/option_card.dart';
import 'lifestyle_occasions_screen.dart';

class StyleGoalsScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/style-goals';
  static const name = 'style_goals';

  const StyleGoalsScreen({super.key});

  @override
  ConsumerState<StyleGoalsScreen> createState() => _StyleGoalsScreenState();
}

class _StyleGoalsScreenState extends ConsumerState<StyleGoalsScreen> {
  final _selected = <int>{};
  bool _submitting = false;

  // Parallel to [_options]: the backend `StyleGoal` literal for each card.
  static const _values = [
    'time_saving',
    'polished',
    'maximize_wardrobe',
    'discover_style',
    'confidence',
    'reduce_clutter',
  ];

  static const _options = [
    ('Spend less time choosing outfits every morning', Icons.schedule_outlined),
    ('Look more polished and put-together', Icons.auto_awesome_outlined),
    ('Make the most of the clothes I already own', Icons.inventory_2_outlined),
    ('Discover my personal style', Icons.style_outlined),
    ('Feel more confident in what I wear', Icons.favorite_border),
    ('Reduce closet clutter and decision fatigue', Icons.cleaning_services_outlined),
  ];

  Future<void> _onContinue() async {
    if (_submitting || _selected.isEmpty) return;
    final goals = [
      for (final i in _selected) _values[i],
    ];

    setState(() => _submitting = true);
    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .setStyleGoals(goals);
      if (!mounted) return;
      context.goNamed(LifestyleOccasionsScreen.name);
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
    final count = _selected.length;
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Style Goals'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                'Pick the goals that matter most to you. DRAPE will optimize your daily styling experience based on these priorities.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                children: [
                  for (int i = 0; i < _options.length; i++) ...[
                    OptionCard(
                      label: _options[i].$1,
                      trailingIcon: _options[i].$2,
                      selected: _selected.contains(i),
                      selector: OptionSelector.checkbox,
                      onTap: () {
                        if (_submitting) return;
                        setState(() {
                          if (!_selected.add(i)) _selected.remove(i);
                        });
                      },
                    ),
                    if (i < _options.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.taupeSoft),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                children: [
                  Text(
                    '$count SELECTED',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.espresso,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  DrapeButton(
                    label: 'Continue with Selection',
                    loading: _submitting,
                    onPressed: count == 0 ? null : _onContinue,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'STEP 2 OF 4',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.inkSoft,
                          letterSpacing: 1.4,
                        ),
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
