import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/option_card.dart';
import 'age_range_screen.dart';

class ShoppingStyleScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/shopping-style';
  static const name = 'shopping_style';

  const ShoppingStyleScreen({super.key});

  @override
  ConsumerState<ShoppingStyleScreen> createState() =>
      _ShoppingStyleScreenState();
}

class _ShoppingStyleScreenState extends ConsumerState<ShoppingStyleScreen> {
  int? _selected;
  bool _submitting = false;

  // Parallel to [_options]: the backend `ShoppingStyle` literal for each card.
  static const _values = ['womens', 'mens', 'both', 'prefer_not_to_say'];

  static const _options = [
    ('Women’s Fashion', Icons.dry_cleaning_outlined),
    ('Men’s Fashion', Icons.checkroom),
    ('Both / All Styles', Icons.style_outlined),
    ('Prefer not to say', Icons.help_outline),
  ];

  Future<void> _onContinue() async {
    final selected = _selected;
    if (selected == null || _submitting) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .setShoppingStyle(_values[selected]);
      if (!mounted) return;
      context.pushNamed(AgeRangeScreen.name);
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
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Build Your Profile'),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(step: 4, totalSteps: 15),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Text(
                    'What style do you shop for?',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This helps DRAPE suggest the right products and outfit ideas for you.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  for (int i = 0; i < _options.length; i++) ...[
                    OptionCard(
                      label: _options[i].$1,
                      icon: _options[i].$2,
                      selected: _selected == i,
                      onTap: () {
                        if (_submitting) return;
                        setState(() => _selected = i);
                      },
                    ),
                    if (i < _options.length - 1) const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: DrapeButton(
                label: 'Continue',
                loading: _submitting,
                onPressed: _selected == null ? null : _onContinue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
