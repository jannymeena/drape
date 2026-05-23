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
  });

  final bool onboardingCompleted;
  final String? onboardingLastStep;
  final String nextStep;
  final String? shoppingStyle;
  final String? ageRange;
  final List<String>? styleGoals;

  factory OnboardingStatus.fromJson(Map<String, dynamic> json) {
    return OnboardingStatus(
      onboardingCompleted: json['onboarding_completed'] as bool? ?? false,
      onboardingLastStep: json['onboarding_last_step'] as String?,
      nextStep: json['next_step'] as String,
      shoppingStyle: json['shopping_style'] as String?,
      ageRange: json['age_range'] as String?,
      styleGoals: (json['style_goals'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
