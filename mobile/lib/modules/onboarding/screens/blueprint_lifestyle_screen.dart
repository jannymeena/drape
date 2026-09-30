import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import '../widgets/option_card.dart';
import 'blueprint_habits_screen.dart';

/// Step 5 of 7 — work context: what you do, how you dress for it, and where
/// you want to make a better impression.
///
/// Occupation is free text with common suggestions; the dress-code question
/// only applies to people who are currently working, so it's optional and
/// clears itself when the occupation is blank.
class BlueprintLifestyleScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/lifestyle';
  static const name = 'blueprint_lifestyle';

  const BlueprintLifestyleScreen({super.key});

  @override
  ConsumerState<BlueprintLifestyleScreen> createState() =>
      _BlueprintLifestyleScreenState();
}

class _BlueprintLifestyleScreenState
    extends ConsumerState<BlueprintLifestyleScreen> {
  static const _suggestions = [
    'Marketing',
    'Media / Communications',
    'Business',
    'Self-Employed',
    'Healthcare',
    'Education',
    'Engineering / Tech',
    'Student',
    'Not currently working',
  ];

  static const _dressCodes = <(String, String)>[
    ('casual', 'Casual'),
    ('business_casual', 'Business Casual'),
    ('business_formal', 'Business Formal'),
    ('uniform_other', 'Uniform / Other'),
  ];

  static const _impressions = <(String, String)>[
    ('work', 'Work / Professional settings'),
    ('dating', 'Dating / Social situations'),
    ('both', 'Both equally'),
    ('content', 'I’m content where I am'),
  ];

  late final TextEditingController _occupation;
  final _dressCodeQuestion = GlobalKey();
  final _impressionQuestion = GlobalKey();

  String? _dressCode;
  String? _impression;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _occupation = TextEditingController(text: saved.occupation ?? '');
    _dressCode = saved.dressCode;
    _impression = saved.impressionGoal;
  }

  @override
  void dispose() {
    _occupation.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final impression = _impression;
    if (impression == null || _submitting) return;

    final occupation = _occupation.text.trim();
    setState(() => _submitting = true);
    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .setBlueprintLifestyle(
            occupation: occupation.isEmpty ? null : occupation,
            // A dress code without a job is meaningless — drop it rather than
            // storing an answer to a question the user never saw.
            dressCode: occupation.isEmpty ? null : _dressCode,
            impressionGoal: impression,
          );
      if (!mounted) return;
      context.pushNamed(BlueprintHabitsScreen.name);
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
    final hasOccupation = _occupation.text.trim().isNotEmpty;
    return BlueprintScaffold(
      step: 5,
      canContinue: _impression != null,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'What do you do for work?',
          subtitle: 'Helps us match outfits to your day-to-day.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _occupation,
          textCapitalization: TextCapitalization.words,
          style: BlueprintText.option(context),
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Search your occupation…',
            hintStyle: BlueprintText.option(context)
                .copyWith(color: AppColors.taupe),
            prefixIcon: const Icon(Icons.search, color: AppColors.taupe),
            filled: true,
            fillColor: AppColors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.taupeSoft),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.taupeSoft),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.espresso, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _suggestions)
              _Pill(
                label: s,
                selected: _occupation.text.trim() == s,
                onTap: () {
                  if (_submitting) return;
                  final firstAnswer = _occupation.text.trim().isEmpty;
                  setState(() {
                    _occupation.text = _occupation.text.trim() == s ? '' : s;
                  });
                  if (firstAnswer) revealNextQuestion(_dressCodeQuestion);
                },
              ),
          ],
        ),
        const SizedBox(height: 28),
        BlueprintQuestion(
          key: _dressCodeQuestion,
          title: 'What’s the dress code like?',
          subtitle: hasOccupation
              ? 'Pick the one you dress for most often.'
              : 'Skipped automatically if you’re not currently working.',
        ),
        const SizedBox(height: 16),
        // Disabled rather than hidden: hiding it would reflow the page under
        // the user's thumb as they type an occupation.
        Opacity(
          opacity: hasOccupation ? 1 : 0.4,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (value, label) in _dressCodes)
                _Pill(
                  label: label,
                  selected: _dressCode == value,
                  onTap: () {
                    if (_submitting || !hasOccupation) return;
                    final firstAnswer = _dressCode == null;
                    setState(
                      () => _dressCode = _dressCode == value ? null : value,
                    );
                    if (firstAnswer) revealNextQuestion(_impressionQuestion);
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        BlueprintQuestion(
          key: _impressionQuestion,
          title: 'Where do you want to make a better impression?',
        ),
        const SizedBox(height: 16),
        for (final (value, label) in _impressions) ...[
          OptionCard(
            label: label,
            selected: _impression == value,
            onTap: () {
              if (_submitting) return;
              setState(() => _impression = value);
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Text(
            label,
            style: BlueprintText.option(context).copyWith(
              color: selected ? AppColors.white : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
