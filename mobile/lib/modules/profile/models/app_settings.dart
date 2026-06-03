/// Mirrors the backend `SettingsResponse` (`app/schemas/settings.py`) from
/// `GET/PATCH /settings`.
library;

class AppSettings {
  const AppSettings({
    required this.pushEnabled,
    required this.dailyOutfitSuggestions,
    required this.outfitReminders,
    required this.shoppingSuggestions,
    required this.wardrobeInsights,
    required this.quietHoursEnabled,
    required this.emailWeeklySummary,
    required this.emailProductDeals,
    required this.emailProOffers,
    required this.theme,
    required this.unitSystem,
    this.stylePreferences,
  });

  final bool pushEnabled;
  final bool dailyOutfitSuggestions;
  final bool outfitReminders;
  final bool shoppingSuggestions;
  final bool wardrobeInsights;
  final bool quietHoursEnabled;
  final bool emailWeeklySummary;
  final bool emailProductDeals;
  final bool emailProOffers;

  /// `light` | `dark` | `auto`.
  final String theme;

  /// `metric` | `imperial`.
  final String unitSystem;
  final Map<String, dynamic>? stylePreferences;

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    bool b(String k, [bool d = false]) => json[k] as bool? ?? d;
    return AppSettings(
      pushEnabled: b('push_enabled', true),
      dailyOutfitSuggestions: b('daily_outfit_suggestions', true),
      outfitReminders: b('outfit_reminders', true),
      shoppingSuggestions: b('shopping_suggestions', true),
      wardrobeInsights: b('wardrobe_insights', true),
      quietHoursEnabled: b('quiet_hours_enabled'),
      emailWeeklySummary: b('email_weekly_summary', true),
      emailProductDeals: b('email_product_deals'),
      emailProOffers: b('email_pro_offers'),
      theme: json['theme'] as String? ?? 'light',
      unitSystem: json['unit_system'] as String? ?? 'metric',
      stylePreferences: json['style_preferences'] as Map<String, dynamic>?,
    );
  }
}
