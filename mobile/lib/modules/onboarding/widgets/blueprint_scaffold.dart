import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// How many steps the Style Blueprint has. Single source of truth for the
/// "Step n of 7" pill and the progress line.
const int kBlueprintSteps = 7;

/// The one type scale every onboarding screen uses.
///
/// Onboarding used to mix `headlineLarge` (32sp serif), `headlineMedium`
/// (28sp) and `titleLarge` (22sp) for what is the same thing — a question at
/// the top of a step — so consecutive screens jumped size mid-flow. Every
/// screen now pulls its text style from here instead of reaching into
/// `Theme.of(context).textTheme` directly, so the scale can only change in one
/// place.
class BlueprintText {
  BlueprintText._();

  /// The question at the top of a section. 22sp semibold.
  static TextStyle question(BuildContext context) =>
      Theme.of(context).textTheme.titleLarge!.copyWith(
            color: AppColors.ink,
            height: 1.25,
          );

  /// The explanatory line under a question. 13sp.
  static TextStyle subtitle(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            height: 1.4,
            color: AppColors.inkSoft,
          );

  /// The label on a selectable option (card, row, radio). 15sp medium.
  static TextStyle option(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: AppColors.ink,
          );

  /// Secondary copy inside an option, under its label. 13sp.
  static TextStyle optionSupport(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            height: 1.35,
            color: AppColors.inkSoft,
          );

  /// A compact label: chips, palette captions, slider endpoints. 12sp medium.
  static TextStyle caption(BuildContext context) =>
      Theme.of(context).textTheme.labelMedium!.copyWith(
            color: AppColors.inkSoft,
          );
}

/// A question heading plus its optional explanatory line, at the shared scale.
class BlueprintQuestion extends StatelessWidget {
  final String title;
  final String? subtitle;

  const BlueprintQuestion({super.key, required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: BlueprintText.question(context)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: BlueprintText.subtitle(context)),
        ],
      ],
    );
  }
}

/// Shared chrome for the seven Style Blueprint steps: a back button and a
/// "Step n of 7" pill, a progress line, the scrollable question list, and a
/// sticky Continue button.
///
/// Screens supply only [children] and their own submit handling. Keeping the
/// header, spacing and button here is what makes the seven steps read as one
/// flow — a screen that builds its own `Scaffold` will drift.
class BlueprintScaffold extends StatelessWidget {
  /// 1-based position in the flow. Drives the pill and the progress line.
  final int step;

  /// The questions, in order. Rendered into a scrolling list with the standard
  /// 24dp horizontal gutter.
  final List<Widget> children;

  /// Primary button label.
  final String buttonLabel;

  /// False disables the button (an unanswered required question).
  final bool canContinue;

  /// Shows a spinner in the button while the step is being saved.
  final bool loading;

  final VoidCallback onContinue;

  const BlueprintScaffold({
    super.key,
    required this.step,
    required this.children,
    required this.onContinue,
    this.buttonLabel = 'Continue',
    this.canContinue = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(step: step),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: children,
              ),
            ),
            _ContinueBar(
              label: buttonLabel,
              enabled: canContinue,
              loading: loading,
              onPressed: onContinue,
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final int step;
  const _Header({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 24, 0),
      child: Column(
        children: [
          Row(
            children: [
              // Step 1 is the flow's entry point, so there may be nothing to
              // pop back to — show the button only when there is.
              if (Navigator.of(context).canPop())
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.arrow_back_ios_new, size: 20),
                  color: AppColors.ink,
                  tooltip: 'Go back',
                )
              else
                const SizedBox(width: 48, height: 48),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.tanFixed,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Step $step of $kBlueprintSteps',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.espressoDark,
                        letterSpacing: 0.2,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: step / kBlueprintSteps,
                minHeight: 4,
                backgroundColor: AppColors.sand,
                valueColor: const AlwaysStoppedAnimation(AppColors.espresso),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContinueBar extends StatelessWidget {
  final String label;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _ContinueBar({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.sand)),
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled && !loading ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.espresso,
            disabledBackgroundColor: AppColors.taupeSoft,
            foregroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(AppColors.white),
                  ),
                )
              : Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w600,
                      ),
                ),
        ),
      ),
    );
  }
}
