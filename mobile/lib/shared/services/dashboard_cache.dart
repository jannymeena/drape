import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../modules/today/models/today_dashboard.dart';

/// Non-sensitive local cache of the last Today dashboard frame, for
/// stale-while-revalidate: on a cold start the screen paints the cached outfits
/// instantly while the fresh frame loads.
///
/// Backed by `shared_preferences` (not secure storage — there are no secrets
/// here). Every read is defensive: a corrupt or absent entry yields `null` and
/// never throws, so the cache can never crash startup. Cleared on sign-out so a
/// different account on the same device never sees stale outfits.
class DashboardCache {
  static const _key = 'today_dashboard_cache_v1';

  Future<void> save(TodayDashboard dashboard) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(dashboard.toJson()));
    } catch (_) {
      // Best-effort; a cache write must never break the dashboard.
    }
  }

  Future<TodayDashboard?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      return TodayDashboard.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt / old shape — treat as a miss.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {
      // Best-effort.
    }
  }
}
