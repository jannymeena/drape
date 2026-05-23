/// Mirrors the backend `CurrentWeekUsage` (`GET /usage/current-week`) — the
/// weekly free-tier counters that drive the 75% / 90% / 100% usage banner.
library;

class UsageCounters {
  const UsageCounters({
    required this.used,
    required this.limit,
    required this.remaining,
    required this.percentage,
  });

  final int used;
  final int limit;
  final int remaining;
  final double percentage; // 0–100

  factory UsageCounters.fromJson(Map<String, dynamic> json) => UsageCounters(
        used: json['used'] as int,
        limit: json['limit'] as int,
        remaining: json['remaining'] as int,
        percentage: (json['percentage'] as num).toDouble(),
      );
}

class CurrentWeekUsage {
  const CurrentWeekUsage({
    required this.outfits,
    required this.mixAndMatch,
    required this.nextReset,
    required this.subscriptionTier,
    this.lastReset,
  });

  final UsageCounters outfits;
  final UsageCounters mixAndMatch;
  final DateTime nextReset;
  final String subscriptionTier; // free | pro
  final DateTime? lastReset;

  bool get isPro => subscriptionTier == 'pro';

  factory CurrentWeekUsage.fromJson(Map<String, dynamic> json) {
    return CurrentWeekUsage(
      outfits: UsageCounters.fromJson(json['outfits'] as Map<String, dynamic>),
      mixAndMatch:
          UsageCounters.fromJson(json['mix_and_match'] as Map<String, dynamic>),
      nextReset: DateTime.parse(json['next_reset'] as String),
      subscriptionTier: json['subscription_tier'] as String? ?? 'free',
      lastReset: json['last_reset'] == null
          ? null
          : DateTime.parse(json['last_reset'] as String),
    );
  }
}
