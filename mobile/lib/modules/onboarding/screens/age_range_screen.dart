import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../onboarding_controller.dart';
import '../widgets/onboarding_progress_bar.dart';
import '../widgets/option_card.dart';
import 'style_goals_screen.dart';

class AgeRangeScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/age-range';
  static const name = 'age_range';

  const AgeRangeScreen({super.key});

  @override
  ConsumerState<AgeRangeScreen> createState() => _AgeRangeScreenState();
}

class _AgeRangeScreenState extends ConsumerState<AgeRangeScreen> {
  int? _selected;
  bool _submitting = false;

  // Parallel to [_options]: the backend `AgeRange` literal for each card.
  static const _values = ['18-24', '25-34', '35-44', '45-54', '55+', 'prefer_not_to_say'];

  @override
  void initState() {
    super.initState();
    // Prefill from the saved profile when resuming onboarding.
    final saved = ref.read(onboardingControllerProvider).ageRange;
    final i = saved == null ? -1 : _values.indexOf(saved);
    if (i != -1) _selected = i;
  }

  static const _options = [
    '18–24',
    '25–34',
    '35–44',
    '45–54',
    '55+',
    'Prefer not to say',
  ];

  /// Continue uses the current selection; Skip passes null. Both persist the
  /// (optional) age range so the step is recorded for resume, then advance.
  Future<void> _submit({required bool skip}) async {
    if (_submitting) return;
    final value = skip || _selected == null ? null : _values[_selected!];

    setState(() => _submitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).setAgeRange(value);
      if (!mounted) return;
      context.pushNamed(StyleGoalsScreen.name);
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
      appBar: DrapeAppBar(
        title: 'Build Your Profile',
        actions: [
          TextButton(
            onPressed: _submitting ? null : () => _submit(skip: true),
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
                        TextSpan(text: ' — helps ZOURA suggest age-appropriate styles. You can skip this.'),
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
                      onTap: () {
                        if (_submitting) return;
                        setState(() => _selected = i);
                      },
                    ),
                    if (i < _options.length - 1) const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: _submitting ? null : () => _submit(skip: true),
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
                loading: _submitting,
                onPressed: () => _submit(skip: false),
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
