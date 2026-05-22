/// Mirrors the backend `UserResponse` (see `app/schemas/user.py`) returned by
/// `GET /users/me`. This is the hydrated identity, distinct from [AuthResponse]
/// (which carries tokens + onboarding routing from login/signup).
class CurrentUser {
  const CurrentUser({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    required this.createdAt,
  });

  final String id;
  final String email;
  final String displayName;

  /// `customer` | `admin`.
  final String role;
  final DateTime createdAt;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'customer',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
