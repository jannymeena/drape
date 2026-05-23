import 'outfit.dart';

/// Mirrors the backend `TodayDashboardResponse` (`GET /today/dashboard`).
class TodayDashboard {
  const TodayDashboard({
    required this.user,
    required this.outfits,
    required this.usage,
    required this.banners,
    this.weather,
  });

  final TodayUser user;
  final List<Outfit> outfits;
  final TodayUsage usage;
  final TodayBanners banners;
  final WeatherContext? weather;

  factory TodayDashboard.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'] as Map<String, dynamic>?;
    return TodayDashboard(
      user: TodayUser.fromJson(json['user'] as Map<String, dynamic>),
      outfits: (json['outfits'] as List<dynamic>)
          .map((e) => Outfit.fromJson(e as Map<String, dynamic>))
          .toList(),
      usage: TodayUsage.fromJson(json['usage'] as Map<String, dynamic>),
      banners: TodayBanners.fromJson(json['banners'] as Map<String, dynamic>),
      weather: weather == null ? null : WeatherContext.fromJson(weather),
    );
  }

  /// Swaps the outfit list after a per-card action (regenerate / log) without
  /// disturbing the rest of the dashboard.
  TodayDashboard copyWith({List<Outfit>? outfits}) {
    return TodayDashboard(
      user: user,
      outfits: outfits ?? this.outfits,
      usage: usage,
      banners: banners,
      weather: weather,
    );
  }
}

class TodayUser {
  const TodayUser({required this.name, this.location, this.timezone});

  final String name;
  final String? location;
  final String? timezone;

  factory TodayUser.fromJson(Map<String, dynamic> json) => TodayUser(
        name: json['name'] as String,
        location: json['location'] as String?,
        timezone: json['timezone'] as String?,
      );
}

/// Daily generation progress (distinct from the weekly free-tier limit, which
/// comes from `GET /usage/current-week`).
class TodayUsage {
  const TodayUsage({
    required this.outfitsGeneratedToday,
    required this.outfitTargetPerDay,
    this.resetsAt,
  });

  final int outfitsGeneratedToday;
  final int outfitTargetPerDay;
  final DateTime? resetsAt;

  factory TodayUsage.fromJson(Map<String, dynamic> json) => TodayUsage(
        outfitsGeneratedToday: json['outfits_generated_today'] as int? ?? 0,
        outfitTargetPerDay: json['outfit_target_per_day'] as int? ?? 3,
        resetsAt: json['resets_at'] == null
            ? null
            : DateTime.parse(json['resets_at'] as String),
      );
}

class TodayBanners {
  const TodayBanners({
    this.starterWardrobe = false,
    this.incompleteProfile = false,
  });

  final bool starterWardrobe;
  final bool incompleteProfile;

  factory TodayBanners.fromJson(Map<String, dynamic> json) => TodayBanners(
        starterWardrobe: json['starter_wardrobe'] as bool? ?? false,
        incompleteProfile: json['incomplete_profile'] as bool? ?? false,
      );
}
