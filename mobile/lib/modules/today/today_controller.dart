import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/analytics_provider.dart';
import '../../shared/providers/network_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../../shared/services/analytics/analytics_events.dart';
import '../../shared/services/analytics/analytics_service.dart';
import '../../shared/services/dashboard_cache.dart';
import '../../shared/services/location_service.dart';
import 'models/log_outfit_result.dart';
import 'models/outfit.dart';
import 'models/today_dashboard.dart';
import 'models/usage.dart';
import 'today_service.dart';

/// State for the Today dashboard.
///
/// The dashboard now loads in two stages so the shell paints instantly:
///   1. [dashboard] is the read-only *frame* (greeting, weather, banners, plus
///      any outfits already generated today). [frameLoading]/[frameError] track
///      that fetch.
///   2. Outfit cards are filled in per-occasion. [pendingOccasions] are the
///      occasions still generating (each shows a skeleton + is in flight, so it
///      doubles as the double-fire guard); [failedOccasions] map an occasion to
///      the error that stopped it (each shows a retry chip). A filled occasion
///      lands in [dashboard].outfits.
///
/// [usage] backs the weekly-limit banner and is best-effort. [regeneratingIds]/
/// [loggingIds] track per-card actions in flight (regenerate / log).
class TodayState {
  const TodayState({
    this.frameLoading = false,
    this.dashboard,
    this.usage,
    this.frameError,
    this.pendingOccasions = const {},
    this.failedOccasions = const {},
    this.regeneratingIds = const {},
    this.loggingIds = const {},
  });

  final bool frameLoading;
  final TodayDashboard? dashboard;
  final CurrentWeekUsage? usage;
  final ApiException? frameError;
  final Set<String> pendingOccasions;
  final Map<String, ApiException> failedOccasions;
  final Set<String> regeneratingIds;
  final Set<String> loggingIds;

  bool get hasData => dashboard != null;

  /// Whether any occasion is still being styled (drives the progress copy).
  bool get isGenerating => pendingOccasions.isNotEmpty;

  TodayState copyWith({
    bool? frameLoading,
    TodayDashboard? dashboard,
    CurrentWeekUsage? usage,
    Set<String>? pendingOccasions,
    Map<String, ApiException>? failedOccasions,
    Set<String>? regeneratingIds,
    Set<String>? loggingIds,
  }) {
    return TodayState(
      frameLoading: frameLoading ?? this.frameLoading,
      dashboard: dashboard ?? this.dashboard,
      usage: usage ?? this.usage,
      frameError: frameError,
      pendingOccasions: pendingOccasions ?? this.pendingOccasions,
      failedOccasions: failedOccasions ?? this.failedOccasions,
      regeneratingIds: regeneratingIds ?? this.regeneratingIds,
      loggingIds: loggingIds ?? this.loggingIds,
    );
  }
}

class TodayController extends StateNotifier<TodayState> {
  TodayController(this._service, this._cache, this._analytics)
      : super(const TodayState());

  final TodayService _service;
  final DashboardCache _cache;
  final AnalyticsService _analytics;

  /// Device coords from the most recent [loadFrame], reused so each per-occasion
  /// fill personalizes weather the same way the frame did.
  DeviceCoords? _coords;

  /// Loads the read-only frame (fast) and weekly usage (best-effort), then fans
  /// out per-occasion generation in PARALLEL. Keeps any previously loaded
  /// dashboard visible while refreshing (stale-while-revalidate), and never
  /// leaves [frameLoading] stuck — every exit clears it.
  Future<void> loadFrame() async {
    // Stale-while-revalidate: paint last-known outfits instantly on cold start.
    // Display-only — we never fan out from the cached pending set; the fresh
    // frame below is authoritative for what still needs generating.
    if (state.dashboard == null) {
      final cached = await _cache.load();
      if (cached != null && state.dashboard == null) {
        state = state.copyWith(dashboard: cached);
      }
    }

    state = TodayState(
      frameLoading: true,
      dashboard: state.dashboard,
      usage: state.usage,
      pendingOccasions: state.pendingOccasions,
      failedOccasions: state.failedOccasions,
      regeneratingIds: state.regeneratingIds,
      loggingIds: state.loggingIds,
    );

    // Best-effort device location; null falls back to the backend default.
    final coords = await currentDeviceCoords();
    _coords = coords;

    final Future<CurrentWeekUsage?> usageFuture = _service
        .getCurrentWeekUsage()
        .then<CurrentWeekUsage?>((u) => u)
        .catchError((_) => null);

    final TodayDashboard frame;
    try {
      frame = await _service.getFrame(lat: coords?.lat, lon: coords?.lon);
    } on ApiException catch (e) {
      _setFrameError(e, await usageFuture);
      return;
    } catch (_) {
      _setFrameError(
        const ApiException(
          code: 'error',
          message:
              'Something went wrong loading your dashboard. Please try again.',
        ),
        await usageFuture,
      );
      return;
    }

    final usage = await usageFuture;
    final framePending = frame.pendingOccasions.toSet();
    // Fire only occasions not already in flight (guards rapid pull-to-refresh).
    final toFire = framePending.difference(state.pendingOccasions);
    // Drop stale failures the frame no longer reports as pending (e.g. filled
    // on another device); keep failures still pending so their retry chip stays.
    final failed = {
      for (final entry in state.failedOccasions.entries)
        if (framePending.contains(entry.key) && !toFire.contains(entry.key))
          entry.key: entry.value,
    };

    state = TodayState(
      dashboard: frame,
      usage: usage,
      pendingOccasions: framePending.difference(failed.keys.toSet()),
      failedOccasions: failed,
      regeneratingIds: state.regeneratingIds,
      loggingIds: state.loggingIds,
    );
    _persist();

    for (final occasion in toFire) {
      unawaited(_fill(occasion));
    }
  }

  /// Persists the current dashboard (frame + filled outfits) for the next cold
  /// start. Best-effort — failures are swallowed by [DashboardCache].
  void _persist() {
    final dashboard = state.dashboard;
    if (dashboard != null) unawaited(_cache.save(dashboard));
  }

  void _setFrameError(ApiException error, CurrentWeekUsage? usage) {
    state = TodayState(
      frameError: error,
      dashboard: state.dashboard,
      usage: usage ?? state.usage,
      pendingOccasions: state.pendingOccasions,
      failedOccasions: state.failedOccasions,
      regeneratingIds: state.regeneratingIds,
      loggingIds: state.loggingIds,
    );
  }

  /// Generates one occasion's outfit and folds it into the dashboard. A failure
  /// is isolated to that occasion (its card flips to a retry chip); the rest of
  /// the dashboard is untouched.
  Future<void> _fill(String occasion) async {
    try {
      final outfit = await _service.generateOccasion(
        occasion,
        lat: _coords?.lat,
        lon: _coords?.lon,
      );
      final dashboard = state.dashboard;
      if (dashboard == null) return;
      // Replace any existing outfit for this occasion, else append.
      final outfits = [
        for (final o in dashboard.outfits)
          if (o.occasion != occasion) o,
        outfit,
      ];
      state = state.copyWith(
        dashboard: dashboard.copyWith(outfits: outfits),
        pendingOccasions: {...state.pendingOccasions}..remove(occasion),
        failedOccasions: {...state.failedOccasions}..remove(occasion),
      );
      _persist();
    } on ApiException catch (e) {
      _markOccasionFailed(occasion, e);
    } catch (_) {
      _markOccasionFailed(
        occasion,
        const ApiException(
          code: 'error',
          message: 'Could not style this look. Tap to try again.',
        ),
      );
    }
  }

  void _markOccasionFailed(String occasion, ApiException error) {
    state = state.copyWith(
      pendingOccasions: {...state.pendingOccasions}..remove(occasion),
      failedOccasions: {...state.failedOccasions, occasion: error},
    );
  }

  /// Generates one occasion on demand — the chip row's "Generate" CTA for an
  /// occasion the frame didn't schedule, and the failed card's retry. No-op if
  /// it's already generating. Refreshes usage afterwards (an on-demand
  /// generation consumes an outfit credit).
  Future<void> generateOccasion(String occasion) async {
    if (state.pendingOccasions.contains(occasion)) return;
    state = state.copyWith(
      pendingOccasions: {...state.pendingOccasions, occasion},
      failedOccasions: {...state.failedOccasions}..remove(occasion),
    );
    await _fill(occasion);
    unawaited(_refreshUsage());
  }

  /// Regenerates one outfit in place. The backend returns a *new* outfit row
  /// (different id, different items) for the same occasion, so we swap it into
  /// the old card's slot. Throws [ApiException] (incl. 429 `limit_reached`) to
  /// the caller for UI feedback; the spinner always clears via `finally`.
  Future<void> regenerate(String outfitId) async {
    _markBusy(regenerating: outfitId, busy: true);
    try {
      final fresh = await _service.regenerateOutfit(outfitId);
      _replaceOutfit(outfitId, fresh);
      _analytics.capture(
        AnalyticsEvents.outfitRegenerated,
        {'occasion': fresh.occasion},
      );
      // A regenerate consumed an outfit credit — refresh the banner counters.
      unawaited(_refreshUsage());
    } finally {
      _markBusy(regenerating: outfitId, busy: false);
    }
  }

  /// Logs an outfit as worn today. Returns the server-authored toast + streak
  /// for the caller to surface. Optimistically marks the card logged on
  /// success. Throws [ApiException] for UI feedback; spinner clears via
  /// `finally`.
  Future<LogOutfitResult> logWorn(String outfitId) async {
    _markBusy(logging: outfitId, busy: true);
    try {
      final result = await _service.logOutfitWorn(outfitId);
      _patchOutfit(
        outfitId,
        (o) => o.copyWith(
          isLogged: true,
          loggedAt: result.loggedAt,
          wornCount: o.wornCount + 1,
        ),
      );
      _analytics.capture(AnalyticsEvents.outfitLogged);
      return result;
    } finally {
      _markBusy(logging: outfitId, busy: false);
    }
  }

  /// Toggles the outfit's favorite flag. Optimistic — flips the heart
  /// immediately and reverts if the request fails.
  Future<void> toggleFavorite(String outfitId) async {
    final current = state.dashboard?.outfits
        .where((o) => o.id == outfitId)
        .firstOrNull
        ?.isFavorite;
    if (current == null) return;
    _patchOutfit(outfitId, (o) => o.copyWith(isFavorite: !current));
    try {
      final server = await _service.toggleFavorite(outfitId);
      _patchOutfit(outfitId, (o) => o.copyWith(isFavorite: server));
    } on ApiException {
      _patchOutfit(outfitId, (o) => o.copyWith(isFavorite: current)); // revert
      rethrow;
    }
  }

  /// Applies wardrobe item swaps to an outfit and folds the new lineup +
  /// recomputed score back into the card. Throws [ApiException] (429
  /// `limit_reached` / 400 `invalid_swap`) for the caller to surface.
  Future<void> mixAndMatch(
    String outfitId,
    List<({String oldItemId, String newItemId})> swaps,
  ) async {
    final result = await _service.mixAndMatch(outfitId, swaps);
    _patchOutfit(
      outfitId,
      (o) => o.copyWith(items: result.items, compatibilityScore: result.score),
    );
    _analytics.capture(
      AnalyticsEvents.mixAndMatchSaved,
      {'swaps': swaps.length},
    );
    // A mix consumes a `mix_and_match` credit — refresh the banner counters.
    unawaited(_refreshUsage());
  }

  // --- internals -----------------------------------------------------------

  void _markBusy({String? regenerating, String? logging, required bool busy}) {
    var regenSet = state.regeneratingIds;
    var logSet = state.loggingIds;
    if (regenerating != null) {
      regenSet = {...regenSet};
      busy ? regenSet.add(regenerating) : regenSet.remove(regenerating);
    }
    if (logging != null) {
      logSet = {...logSet};
      busy ? logSet.add(logging) : logSet.remove(logging);
    }
    state = state.copyWith(regeneratingIds: regenSet, loggingIds: logSet);
  }

  void _replaceOutfit(String oldId, Outfit fresh) {
    _patchOutfitList((o) => o.id == oldId ? fresh : o);
  }

  void _patchOutfit(String id, Outfit Function(Outfit) update) {
    _patchOutfitList((o) => o.id == id ? update(o) : o);
  }

  void _patchOutfitList(Outfit Function(Outfit) map) {
    final dashboard = state.dashboard;
    if (dashboard == null) return;
    final outfits = dashboard.outfits.map(map).toList();
    state = state.copyWith(dashboard: dashboard.copyWith(outfits: outfits));
  }

  Future<void> _refreshUsage() async {
    try {
      final usage = await _service.getCurrentWeekUsage();
      state = state.copyWith(usage: usage);
    } on ApiException {
      // Best-effort; the stale banner is fine until the next full load.
    }
  }
}

final todayControllerProvider =
    StateNotifierProvider<TodayController, TodayState>((ref) {
  // User-scoped: rebuilt on login/logout so stale-while-revalidate never
  // paints the previous account's dashboard for the next one.
  ref.watch(sessionEpochProvider);
  return TodayController(
    ref.read(todayServiceProvider),
    ref.read(dashboardCacheProvider),
    ref.read(analyticsProvider),
  );
});
