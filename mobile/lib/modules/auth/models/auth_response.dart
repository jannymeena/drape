/// Mirrors the backend `AuthResponse` (see `app/schemas/auth.py`) returned by
/// signup, login, and refresh.
class AuthResponse {
  const AuthResponse({
    required this.userId,
    required this.email,
    required this.accessToken,
    required this.refreshToken,
    required this.tokenType,
    required this.onboardingCompleted,
    required this.nextStep,
  });

  final String userId;
  final String email;
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final bool onboardingCompleted;

  /// e.g. `age_range`, `measurements_step_8`, `today_dashboard` — drives
  /// onboarding resume via `routeForNextStep` (see `resume_route_map.dart`).
  final String nextStep;

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      userId: json['user_id'] as String,
      email: json['email'] as String,
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      onboardingCompleted: (json['onboarding_completed'] as bool?) ?? false,
      nextStep: (json['next_step'] as String?) ?? '',
    );
  }
}
