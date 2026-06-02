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
    this.ageRange,
    this.location,
    this.timezone,
    this.gender,
    this.phone,
    this.shoppingStyle,
    this.styleGoals,
  });

  final String id;
  final String email;
  final String displayName;

  /// `customer` | `admin`.
  final String role;
  final DateTime createdAt;

  // Profile-tab fields. Null when the user hasn't set them yet; the Edit Profile
  // form rehydrates from these instead of falling back to placeholders.
  final String? ageRange;
  final String? location;
  final String? timezone;
  final String? gender;
  final String? phone;
  final String? shoppingStyle;
  final List<String>? styleGoals;

  factory CurrentUser.fromJson(Map<String, dynamic> json) {
    return CurrentUser(
      id: json['id'] as String,
      email: json['email'] as String,
      displayName: (json['display_name'] as String?) ?? '',
      role: (json['role'] as String?) ?? 'customer',
      createdAt: DateTime.parse(json['created_at'] as String),
      ageRange: json['age_range'] as String?,
      location: json['location'] as String?,
      timezone: json['timezone'] as String?,
      gender: json['gender'] as String?,
      phone: json['phone'] as String?,
      shoppingStyle: json['shopping_style'] as String?,
      styleGoals: (json['style_goals'] as List<dynamic>?)?.cast<String>(),
    );
  }
}
