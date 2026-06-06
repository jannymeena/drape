import 'outfit.dart';

/// Mirrors the backend `TodayDashboardResponse` (`GET /today/dashboard`).
///
/// The dashboard is a read-only "frame": chrome data + any outfits already
/// generated today + the occasions still pending. Outfit cards are filled in
/// per-occasion via `POST /today/outfits`, so the shell can paint instantly.
class TodayDashboard {
  const TodayDashboard({
    required this.user,
    required this.outfits,
    required this.usage,
    required this.banners,
    this.weather,
    this.wardrobeReady = false,
    this.pendingOccasions = const [],
  });

  final TodayUser user;
  final List<Outfit> outfits;
  final TodayUsage usage;
  final TodayBanners banners;
  final WeatherContext? weather;

  /// Whether the user has enough wardrobe items to generate outfits at all.
  /// Drives the "add items" empty state vs. the generating/skeleton state.
  final bool wardrobeReady;

  /// Occasions that still need a today-outfit — drives the skeleton cards.
  final List<String> pendingOccasions;

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
      wardrobeReady: json['wardrobe_ready'] as bool? ?? false,
      pendingOccasions:
          (json['pending_occasions'] as List<dynamic>? ?? const [])
              .map((e) => e as String)
              .toList(),
    );
  }

  /// Serializes back to the backend JSON shape so the dashboard can be cached
  /// (and re-parsed via [fromJson]) for instant stale-while-revalidate paint.
  Map<String, dynamic> toJson() => {
        'user': user.toJson(),
        'outfits': outfits.map((o) => o.toJson()).toList(),
        'usage': usage.toJson(),
        'banners': banners.toJson(),
        'weather': weather?.toJson(),
        'wardrobe_ready': wardrobeReady,
        'pending_occasions': pendingOccasions,
      };

  /// Swaps fields after a per-card action (regenerate / log / occasion fill)
  /// without disturbing the rest of the dashboard.
  TodayDashboard copyWith({
    List<Outfit>? outfits,
    bool? wardrobeReady,
    List<String>? pendingOccasions,
  }) {
    return TodayDashboard(
      user: user,
      outfits: outfits ?? this.outfits,
      usage: usage,
      banners: banners,
      weather: weather,
      wardrobeReady: wardrobeReady ?? this.wardrobeReady,
      pendingOccasions: pendingOccasions ?? this.pendingOccasions,
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

  Map<String, dynamic> toJson() => {
        'name': name,
        'location': location,
        'timezone': timezone,
      };
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

  Map<String, dynamic> toJson() => {
        'outfits_generated_today': outfitsGeneratedToday,
        'outfit_target_per_day': outfitTargetPerDay,
        'resets_at': resetsAt?.toIso8601String(),
      };
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

  Map<String, dynamic> toJson() => {
        'starter_wardrobe': starterWardrobe,
        'incomplete_profile': incompleteProfile,
      };
}
