import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import 'measurement_guide.dart';

/// Shared chrome for the 8 avatar-measurement steps so they read as one flow:
/// the "Build Your Avatar" app bar, a `STEP n OF 8 — LABEL` marker, the
/// [MeasurementGuide] illustration, a left-aligned title + how-to copy, the
/// caller's [input] field, and a "Keep Going" button.
///
/// Only the layout lives here. Per-screen state — the entered value, optional
/// vs. required gating ([canContinue]), and submit handling ([loading]) — stays
/// in each screen, which builds its own [MeasurementInput] and passes it as
/// [input].
class MeasurementStepScaffold extends StatelessWidget {
  /// 1-based position in the flow, rendered in the step marker.
  final int step;
  final int totalSteps;

  /// Upper-cased suffix after "STEP n OF 8 — ", e.g. `'WAIST'`.
  final String stepLabel;

  /// [MeasurementGuide] region to illustrate, e.g. `'waist'`.
  final String bodyPart;

  /// Headline, e.g. `'Waist'`.
  final String title;

  /// One-line how-to-measure copy under the title.
  final String description;

  /// The measurement field for this step (a [MeasurementInput]).
  final Widget input;

  /// Primary button label. Defaults to the Family-B `'Keep Going'`.
  final String buttonLabel;

  /// Whether the button is enabled (false → disabled). Optional steps pass true.
  final bool canContinue;

  /// Shows a spinner in the button (used by the final submitting step).
  final bool loading;

  final VoidCallback? onContinue;

  const MeasurementStepScaffold({
    super.key,
    required this.step,
    required this.stepLabel,
    required this.bodyPart,
    required this.title,
    required this.description,
    required this.input,
    required this.onContinue,
    this.totalSteps = 8,
    this.buttonLabel = 'Keep Going',
    this.canContinue = true,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Build Your Avatar'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Text(
                'STEP $step OF $totalSteps — $stepLabel',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.espresso,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                children: [
                  MeasurementGuide(bodyPart: bodyPart),
                  const SizedBox(height: 24),
                  Text(title, style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  Text(description,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 28),
                  input,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: DrapeButton(
                label: buttonLabel,
                loading: loading,
                onPressed: canContinue ? onContinue : null,
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
