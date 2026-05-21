import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/option_card.dart';
import 'style_goals_screen.dart';

class AgeRangeScreen extends StatefulWidget {
  static const path = '/onboarding/age-range';
  static const name = 'age_range';

  const AgeRangeScreen({super.key});

  @override
  State<AgeRangeScreen> createState() => _AgeRangeScreenState();
}

class _AgeRangeScreenState extends State<AgeRangeScreen> {
  int? _selected;

  static const _options = [
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55+',
    'Prefer not to say',
  ];

  void _next() => context.goNamed(StyleGoalsScreen.name);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DrapeAppBar(
        title: 'Build Your Profile',
        actions: [
          TextButton(
            onPressed: _next,
            style: TextButton.styleFrom(foregroundColor: AppColors.espresso),
            child: const Text('Skip',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const OnboardingProgressBar(step: 5, totalSteps: 15),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                children: [
                  Text(
                    "What's your age range?",
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  Text.rich(
                    TextSpan(
                      style: Theme.of(context).textTheme.bodyMedium,
                      children: const [
                        TextSpan(
                          text: 'Optional',
                          style: TextStyle(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        TextSpan(text: ' — helps DRAPE suggest age-appropriate styles. You can skip this.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  for (int i = 0; i < _options.length; i++) ...[
                    OptionCard(
                      label: _options[i],
                      icon: i == _options.length - 1
                          ? Icons.visibility_off_outlined
                          : Icons.calendar_month_outlined,
                      selected: _selected == i,
                      onTap: () => setState(() => _selected = i),
                    ),
                    if (i < _options.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _next,
                      child: Text(
                        '[Skip This Step]',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.inkSoft,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: DrapeButton(
                label: 'Continue',
                onPressed: _next,
                leading: const Icon(Icons.arrow_forward,
                    color: AppColors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
