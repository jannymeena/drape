import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Onboarding step indicator. For a small number of steps (the measurement /
/// avatar flow is 8) this renders the numbered-circle stepper: completed steps
/// show a check, the current step shows its highlighted number, upcoming steps
/// are outlined, all joined by connectors that fill as you advance.
///
/// Beyond [_circleStepperMax] steps the circles get too cramped on a phone, so
/// it falls back to a slim bar + "STEP X OF Y" counter.
class OnboardingProgressBar extends StatelessWidget {
  final int step;
  final int totalSteps;

  /// Largest [totalSteps] that still renders legibly as numbered circles.
  static const _circleStepperMax = 10;

  const OnboardingProgressBar({
    super.key,
    required this.step,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    if (totalSteps > _circleStepperMax) {
      return _SlimBar(step: step, totalSteps: totalSteps);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
      child: Row(
        children: [
          for (var i = 1; i <= totalSteps; i++) ...[
            _StepCircle(
              index: i,
              state: i < step
                  ? _StepState.done
                  : i == step
                      ? _StepState.current
                      : _StepState.upcoming,
            ),
            if (i < totalSteps)
              Expanded(child: _Connector(filled: i < step)),
          ],
        ],
      ),
    );
  }
}

enum _StepState { done, current, upcoming }

class _StepCircle extends StatelessWidget {
  final int index;
  final _StepState state;

  const _StepCircle({required this.index, required this.state});

  @override
  Widget build(BuildContext context) {
    const size = 28.0;
    final filled = state != _StepState.upcoming;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: filled ? AppColors.espresso : AppColors.ivory,
        shape: BoxShape.circle,
        border: Border.all(
          color: filled ? AppColors.espresso : AppColors.tanFixed,
          width: 2,
        ),
        boxShadow: state == _StepState.current
            ? [
                BoxShadow(
                  color: AppColors.espresso.withValues(alpha: 0.25),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: state == _StepState.done
          ? const Icon(Icons.check, color: AppColors.white, size: 16)
          : Text(
              '$index',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: state == _StepState.current
                        ? AppColors.white
                        : AppColors.taupe,
                    fontWeight: FontWeight.w700,
                  ),
            ),
    );
  }
}

class _Connector extends StatelessWidget {
  final bool filled;
  const _Connector({required this.filled});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: filled ? AppColors.espresso : AppColors.tanFixed,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Slim linear bar + counter — fallback for flows with many steps.
class _SlimBar extends StatelessWidget {
  final int step;
  final int totalSteps;
  const _SlimBar({required this.step, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / totalSteps,
              minHeight: 4,
              backgroundColor: AppColors.tanFixed,
              valueColor: const AlwaysStoppedAnimation(AppColors.espresso),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'STEP $step OF $totalSteps',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.inkSoft,
                  letterSpacing: 1.6,
                ),
          ),
        ],
      ),
    );
  }
}
