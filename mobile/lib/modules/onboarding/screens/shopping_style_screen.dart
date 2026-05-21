import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/option_card.dart';
import 'age_range_screen.dart';

class ShoppingStyleScreen extends StatefulWidget {
  static const path = '/onboarding/shopping-style';
  static const name = 'shopping_style';

  const ShoppingStyleScreen({super.key});

  @override
  State<ShoppingStyleScreen> createState() => _ShoppingStyleScreenState();
}

class _ShoppingStyleScreenState extends State<ShoppingStyleScreen> {
  int? _selected;

  static const _options = [
    ('Women’s Fashion', Icons.dry_cleaning_outlined),
    ('Men’s Fashion', Icons.checkroom),
    ('Both / All Styles', Icons.style_outlined),
    ('Prefer not to say', Icons.help_outline),
  ];

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
                      onTap: () => setState(() => _selected = i),
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
                onPressed: _selected == null
                    ? null
                    : () => context.goNamed(AgeRangeScreen.name),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
