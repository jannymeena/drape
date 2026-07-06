/// Mirrors the backend `OnboardingStatusResponse` (`GET /profile/onboarding-status`).
///
/// [nextStep] / [onboardingLastStep] are the backend's `OnboardingStep` string
/// literals (e.g. `age_range`, `measurements_step_3`, `avatar_reveal`); the
/// client maps [nextStep] to a route when resuming onboarding on launch.
/// The `shopping_style` / `age_range` / `style_goals` echoes let the resume
/// flow prefill earlier selections.
class OnboardingStatus {
  const OnboardingStatus({
    required this.onboardingCompleted,
    required this.onboardingLastStep,
    required this.nextStep,
    this.shoppingStyle,
    this.ageRange,
    this.styleGoals,
    this.measurementStepsCompleted = 0,
    this.nextIncompleteStep,
  });

  final bool onboardingCompleted;
  final String? onboardingLastStep;
  final String nextStep;
  final String? shoppingStyle;
  final String? ageRange;
  final List<String>? styleGoals;

  /// Measurement progress for the Today resume banner: 0–8 fields saved, and
  /// the next incomplete measurement id — null once the 7 required are in
  /// (weight is optional and never blocks completion).
  final int measurementStepsCompleted;
  final String? nextIncompleteStep;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      onboardingLastStep: json['onboarding_last_step'] as String?,
      nextStep: json['next_step'] as String,
      shoppingStyle: json['shopping_style'] as String?,
      ageRange: json['age_range'] as String?,
      styleGoals: (json['style_goals'] as List<dynamic>?)?.cast<String>(),
      measurementStepsCompleted:
          json['measurement_steps_completed'] as int? ?? 0,
      nextIncompleteStep: json['next_incomplete_step'] as String?,
    );
  }
}
