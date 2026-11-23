import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../modules/today/models/today_dashboard.dart';
import 'storage_service.dart';

/// Non-sensitive local cache of the last Today dashboard frame, for
/// stale-while-revalidate: on a cold start the screen paints the cached outfits
/// instantly while the fresh frame loads.
///
/// Backed by `shared_preferences` (not secure storage — there are no secrets
/// here). Every read is defensive: a corrupt or absent entry yields `null` and
/// never throws, so the cache can never crash startup.
///
/// An entry belongs to one user on one day: it's stamped with the signed-in
/// user's id and the local date, and [load] treats any mismatch as a miss.
/// Today's outfits are per-day, and a frame cached under another account
/// (or one left behind by a sign-out that skipped [clear]) must never paint —
/// it once showed months-old outfits from a retired starter wardrobe.
/// It's also cleared on every sign-out and sign-in.
class DashboardCache {
  DashboardCache({StorageService? storage, DateTime Function()? now})
      : _storage = storage ?? StorageService(),
        _now = now ?? DateTime.now;

  final StorageService _storage;
  final DateTime Function() _now;

  // v2: the entry is an envelope {user_id, day, dashboard}. v1 entries (bare
  // dashboards, no owner) are never read — [clear] removes them too.
  static const _key = 'today_dashboard_cache_v2';
  static const _legacyKeys = ['today_dashboard_cache_v1'];

  String _today() {
    final d = _now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  Future<void> save(TodayDashboard dashboard) async {
    try {
      final userId = await _storage.getUserId();
      if (userId == null) return; // no owner to stamp — don't cache
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'user_id': userId,
          'day': _today(),
          'dashboard': dashboard.toJson(),
        }),
      );
    } catch (_) {
      // Best-effort; a cache write must never break the dashboard.
    }
  }

  Future<TodayDashboard?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return null;
      final entry = jsonDecode(raw) as Map<String, dynamic>;
      final userId = await _storage.getUserId();
      if (userId == null || entry['user_id'] != userId) return null;
      if (entry['day'] != _today()) return null;
      return TodayDashboard.fromJson(entry['dashboard'] as Map<String, dynamic>);
    } catch (_) {
      return null; // corrupt / old shape — treat as a miss.
    }
  }

  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      for (final k in _legacyKeys) {
        await prefs.remove(k);
      }
    } catch (_) {
      // Best-effort.
    }
  }
}
