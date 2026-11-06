import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../shared/theme/app_colors.dart';
import '../resume_route_map.dart';
import 'pipeda_note.dart';

/// How many steps the Style Blueprint has. Single source of truth for the
/// "Step n of 8" pill and the progress line.
const int kBlueprintSteps = 8;

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

  /// A Style Blueprint question heading (steps 1–7 and the shape finder):
  /// Newsreader 26 semibold, tight, as the blueprint mockups set it. The
  /// rest of the app's headings are Cormorant Garamond ([question]).
  static TextStyle heading(BuildContext context) => GoogleFonts.newsreader(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    height: 1.25,
    letterSpacing: -0.65,
    color: AppColors.ink,
  );

  /// The question at the top of a section. Serif, semibold.
  static TextStyle question(BuildContext context) => Theme.of(context)
      .textTheme
      .headlineSmall!
      .copyWith(color: AppColors.ink, fontWeight: FontWeight.w600, height: 1.2);

  /// The explanatory line under a question. 13sp.
  static TextStyle subtitle(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(fontSize: 13, height: 1.4, color: AppColors.inkSoft);

  /// The label on a selectable option (card, row, radio). 15sp medium.
  static TextStyle option(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: AppColors.ink,
      );

  /// Secondary copy inside an option, under its label. 13sp.
  static TextStyle optionSupport(BuildContext context) => Theme.of(context)
      .textTheme
      .bodyMedium!
      .copyWith(fontSize: 13, height: 1.35, color: AppColors.inkSoft);

  /// A compact label: chips, palette captions, slider endpoints. 12sp medium.
  static TextStyle caption(BuildContext context) => Theme.of(
    context,
  ).textTheme.labelMedium!.copyWith(color: AppColors.inkSoft);
}

/// A second question on a step, under the main one: DM Sans semibold (18 by
/// default),
/// with an optional line under it ([italic] for an aside).
class BlueprintSubQuestion extends StatelessWidget {
  const BlueprintSubQuestion(
    this.text, {
    super.key,
    this.note,
    this.italic = true,
    this.size = 18,
  });

  final String text;
  final String? note;
  final bool italic;
  final double size;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: body.copyWith(
            fontSize: size,
            fontWeight: FontWeight.w600,
            height: 1.375,
            color: AppColors.ink,
          ),
        ),
        if (note case final n?) ...[
          const SizedBox(height: 2),
          Text(
            n,
            style: body.copyWith(
              fontSize: 12,
              fontStyle: italic ? FontStyle.italic : FontStyle.normal,
              color: AppColors.inkSoft,
            ),
          ),
        ],
      ],
    );
  }
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
        Text(title, style: BlueprintText.heading(context)),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(subtitle!, style: BlueprintText.subtitle(context)),
        ],
      ],
    );
  }
}

/// Brings the question keyed by [next] to the top of the step once a
/// one-answer question has just been answered, so the user can keep going
/// without scrolling. Waits a beat first so the pick visibly registers.
///
/// Call it only when a single-choice question goes from unanswered to
/// answered: multi-select questions are still being chosen, sliders fire
/// while dragging, and re-answering an earlier question shouldn't yank the
/// page forward.
Future<void> revealNextQuestion(GlobalKey next) async {
  await Future<void>.delayed(const Duration(milliseconds: 250));
  final context = next.currentContext;
  if (context == null || !context.mounted) return;
  await Scrollable.ensureVisible(
    context,
    duration: const Duration(milliseconds: 400),
    curve: Curves.easeInOut,
  );
}

/// Shared chrome for the seven Style Blueprint steps: a back button and a
/// "Step n of 8" pill, a progress line, the scrollable question list, and a
/// sticky Continue button.
///
/// Screens supply only [children] and their own submit handling. Keeping the
/// header, spacing and button here is what makes the seven steps read as one
/// flow — a screen that builds its own `Scaffold` will drift.
class BlueprintScaffold extends StatelessWidget {
  /// 1-based position in the flow. Drives the pill and the progress line.
  final int step;

  /// The questions, in order. Rendered into a scrolling list with the standard
  /// 16dp horizontal gutter.
  final List<Widget> children;

  /// Primary button label, with an optional [buttonIcon] after it.
  final String buttonLabel;
  final IconData? buttonIcon;

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
    this.buttonIcon,
    this.canContinue = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    // Dark status-bar icons, set explicitly: the shape finder's dark avatar
    // reveal hands over to step 3, and would otherwise leave them light.
    final scaffold = AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        body: SafeArea(
          child: Column(
            children: [
              _Header(step: step),
              Expanded(
                // Not a lazy ListView: every question is built up front so
                // `revealNextQuestion` can always find the next one.
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  ),
                ),
              ),
              _ContinueBar(
                label: buttonLabel,
                icon: buttonIcon,
                enabled: canContinue,
                loading: loading,
                onPressed: onContinue,
              ),
            ],
          ),
        ),
      ),
    );
    if (step == 1) return scaffold;
    // Steps 2–7 always have a step behind them, so the system back gesture
    // goes there too, instead of closing the app on a resumed step.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goToPreviousStep(context, step);
      },
      child: scaffold,
    );
  }
}

/// Whether this screen's own route has one beneath it. Unlike
/// `Navigator.canPop`, which is about the whole stack, this stays right when a
/// step rebuilds while the next step is pushed on top of it.
bool _hasScreenBelow(BuildContext context) =>
    ModalRoute.of(context)?.canPop ?? false;

/// Back from [step]: pops when the previous step is underneath, otherwise
/// opens it. A resumed flow starts at the saved step on its own (the splash
/// `go`es there), so there's often nothing to pop.
void goToPreviousStep(BuildContext context, int step) {
  if (_hasScreenBelow(context)) {
    // `pop`, not `maybePop`: this runs from inside the PopScope above.
    Navigator.of(context).pop();
  } else if (step > 1) {
    context.goNamed(routeForNextStep('style_blueprint_${step - 1}'));
  }
}

class _Header extends StatelessWidget {
  final int step;
  const _Header({required this.step});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              // Steps 2–7 always lead back to the previous step. Step 1 is
              // the flow's entry point: show back only when there's a screen
              // underneath it.
              if (step > 1 || _hasScreenBelow(context))
                IconButton(
                  onPressed: () => goToPreviousStep(context, step),
                  icon: const Icon(Icons.chevron_left, size: 28),
                  color: AppColors.ink,
                  tooltip: 'Go back',
                )
              else
                const SizedBox(width: 48, height: 48),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ivoryHigh,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Step $step of $kBlueprintSteps',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.ink,
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
  final IconData? icon;
  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;

  const _ContinueBar({
    required this.label,
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: AppColors.white,
        fontWeight: FontWeight.w600,
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.sand)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
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
                  : icon == null
                  ? text
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(child: text),
                        const SizedBox(width: 8),
                        Icon(icon, size: 20, color: AppColors.white),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 8),
          const PipedaNote(),
        ],
      ),
    );
  }
}
