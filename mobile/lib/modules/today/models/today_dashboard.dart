import 'outfit.dart';

/// Mirrors the backend `TodayDashboardResponse` (`GET /today/dashboard`).
///
/// The dashboard is a read-only "frame": chrome data + today's looks if
/// already styled. Today's outfits are styled for the day's plan (Plan a
/// day) in one call (`POST /today/outfits`), so the shell can paint
/// instantly: up to 3 looks from the user's own pieces, or one from the
/// starter wardrobe while it's active ([wardrobeMode]) — never a mix.
class TodayDashboard {
  const TodayDashboard({
    required this.user,
    required this.outfits,
    required this.usage,
    required this.banners,
    this.weather,
    this.weatherAttribution,
    this.wardrobeReady = false,
    this.needsPlan = false,
    this.needsStyling = false,
    this.wardrobeMode = WardrobeMode.wardrobe,
    this.missingRoles = const [],
    this.occasions = const [],
    this.planKey,
  });

  final TodayUser user;
  final List<Outfit> outfits;
  final TodayUsage usage;
  final TodayBanners banners;
  /// Current conditions (not the snapshot an outfit was styled for).
  final WeatherContext? weather;

  /// Required source credit shown on the weather chip (WeatherKit → Apple
  /// Weather mark + data-sources link); null when the source needs none.
  final WeatherAttribution? weatherAttribution;

  /// Whether the wardrobe has anything to style for today's plan (or, when
  /// today isn't planned, enough pieces to style at all). False drives the
  /// "add items" empty state.
  final bool wardrobeReady;

  /// Today isn't planned: the outfit card asks the user to pick what's on.
  final bool needsPlan;

  /// The plan's looks aren't styled yet: a skeleton card shows while the
  /// controller asks for them.
  final bool needsStyling;

  /// Which pieces the looks are made of.
  final WardrobeMode wardrobeMode;

  /// Roles (`top`, `bottom`, `dress`, `shoes`…) that would complete a look,
  /// when [wardrobeReady] is false.
  final List<String> missingRoles;

  /// The plan this frame's outfits were styled for — `occasion|dress_level`
  /// wire values (see [planKeyOf]); null when today wasn't planned. Today
  /// reloads when the day's plan no longer matches it.
  final String? planKey;

  /// `work_day|business` — the key a plan's occasion + dress level make.
  static String planKeyOf(String occasion, String dressLevel) =>
      '$occasion|$dressLevel';

  /// Today's plan in the backend's `day_plans` (today first).
  static String? _planKeyFrom(Object? dayPlans) {
    if (dayPlans is! List || dayPlans.isEmpty) return null;
    final plan = (dayPlans.first as Map<String, dynamic>)['plan'];
    if (plan is! Map<String, dynamic>) return null;
    return planKeyOf(plan['occasion'] as String, plan['dress_level'] as String);
  }

  /// Every occasion the backend's rulebook defines, in display order — the
  /// occasion chips. Empty from an older cached frame.
  final List<OccasionOption> occasions;

  factory TodayDashboard.fromJson(Map<String, dynamic> json) {
    final weather = json['weather'] as Map<String, dynamic>?;
    final attribution = json['weather_attribution'] as Map<String, dynamic>?;
    return TodayDashboard(
      user: TodayUser.fromJson(json['user'] as Map<String, dynamic>),
      outfits: (json['outfits'] as List<dynamic>)
          .map((e) => Outfit.fromJson(e as Map<String, dynamic>))
          .toList(),
      usage: TodayUsage.fromJson(json['usage'] as Map<String, dynamic>),
      banners: TodayBanners.fromJson(json['banners'] as Map<String, dynamic>),
      weather: weather == null ? null : WeatherContext.fromJson(weather),
      weatherAttribution: attribution == null
          ? null
          : WeatherAttribution.fromJson(attribution),
      wardrobeReady: json['wardrobe_ready'] as bool? ?? false,
      needsPlan: json['needs_plan'] as bool? ?? false,
      needsStyling: json['needs_styling'] as bool? ?? false,
      wardrobeMode: WardrobeMode.fromWire(json['wardrobe_mode'] as String?),
      missingRoles: (json['missing_roles'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
      occasions: (json['occasions'] as List<dynamic>? ?? const [])
          .map((e) => OccasionOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      // `plan_key` is the cached form (see toJson); the API sends day_plans.
      planKey: json['plan_key'] as String? ?? _planKeyFrom(json['day_plans']),
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
        'weather_attribution': weatherAttribution?.toJson(),
        'wardrobe_ready': wardrobeReady,
        'needs_plan': needsPlan,
        'needs_styling': needsStyling,
        'wardrobe_mode': wardrobeMode.wire,
        'missing_roles': missingRoles,
        'occasions': occasions.map((o) => o.toJson()).toList(),
        'plan_key': planKey,
      };

  /// Swaps fields after a per-card action (regenerate / log) or the day's
  /// styling without disturbing the rest of the dashboard.
  TodayDashboard copyWith({
    List<Outfit>? outfits,
    bool? wardrobeReady,
    bool? needsStyling,
    List<String>? missingRoles,
  }) {
    return TodayDashboard(
      user: user,
      outfits: outfits ?? this.outfits,
      usage: usage,
      banners: banners,
      weather: weather,
      weatherAttribution: weatherAttribution,
      wardrobeReady: wardrobeReady ?? this.wardrobeReady,
      needsPlan: needsPlan,
      needsStyling: needsStyling ?? this.needsStyling,
      wardrobeMode: wardrobeMode,
      missingRoles: missingRoles ?? this.missingRoles,
      occasions: occasions,
      planKey: planKey,
    );
  }
}

/// Mirrors the backend `StyleTodayResponse` (`POST /today/outfits`): the
/// day's looks in slot order, or none with the roles that would complete
/// one.
class TodayLooks {
  const TodayLooks({required this.outfits, this.missingRoles = const []});

  final List<Outfit> outfits;
  final List<String> missingRoles;

  factory TodayLooks.fromJson(Map<String, dynamic> json) => TodayLooks(
        outfits: (json['outfits'] as List<dynamic>)
            .map((e) => Outfit.fromJson(e as Map<String, dynamic>))
            .toList(),
        missingRoles: (json['missing_roles'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
      );
}

/// Which pieces Today's looks are made of: the starter wardrobe (catalog
/// pieces to shop, one look) while it's active, else the user's own.
enum WardrobeMode {
  starter('starter'),
  wardrobe('wardrobe');

  const WardrobeMode(this.wire);
  final String wire;

  static WardrobeMode fromWire(String? wire) =>
      wire == 'starter' ? starter : wardrobe;
}

/// Mirrors the backend `OccasionOption`: an occasion the stylist can dress
/// for. `daily` ones are filled on Today every day; the rest on demand.
class OccasionOption {
  const OccasionOption({
    required this.key,
    required this.label,
    this.daily = false,
  });

  final String key;
  final String label;
  final bool daily;

  factory OccasionOption.fromJson(Map<String, dynamic> json) => OccasionOption(
        key: json['key'] as String,
        label: json['label'] as String,
        daily: json['daily'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {'key': key, 'label': label, 'daily': daily};
}

/// Mirrors the backend `WeatherAttributionResponse`.
class WeatherAttribution {
  const WeatherAttribution({
    required this.serviceName,
    required this.logoLightUrl,
    required this.logoDarkUrl,
    required this.legalUrl,
  });

  final String serviceName;
  final String logoLightUrl;
  final String logoDarkUrl;
  final String legalUrl;

  factory WeatherAttribution.fromJson(Map<String, dynamic> json) =>
      WeatherAttribution(
        serviceName: json['service_name'] as String,
        logoLightUrl: json['logo_light_url'] as String,
        logoDarkUrl: json['logo_dark_url'] as String,
        legalUrl: json['legal_url'] as String,
      );

  Map<String, dynamic> toJson() => {
        'service_name': serviceName,
        'logo_light_url': logoLightUrl,
        'logo_dark_url': logoDarkUrl,
        'legal_url': legalUrl,
      };
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
