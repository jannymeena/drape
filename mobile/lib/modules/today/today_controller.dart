import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import 'models/log_outfit_result.dart';
import 'models/outfit.dart';
import 'models/today_dashboard.dart';
import 'models/usage.dart';
import 'today_service.dart';

/// State for the Today dashboard. [dashboard] is the source of truth for the
/// home tab; [usage] backs the weekly-limit banner and is best-effort (a usage
/// fetch failure must not blank the dashboard). [error] is set only when the
/// dashboard itself fails to load.
///
/// [regeneratingIds] / [loggingIds] track per-card actions in flight so each
/// outfit can show its own spinner without blocking the rest of the list.
class TodayState {
  const TodayState({
    this.loading = false,
    this.dashboard,
    this.usage,
    this.error,
    this.regeneratingIds = const {},
    this.loggingIds = const {},
  });

  final bool loading;
  final TodayDashboard? dashboard;
  final CurrentWeekUsage? usage;
  final ApiException? error;
  final Set<String> regeneratingIds;
  final Set<String> loggingIds;

  bool get hasData => dashboard != null;

  TodayState copyWith({
    bool? loading,
    TodayDashboard? dashboard,
    CurrentWeekUsage? usage,
    ApiException? error,
    Set<String>? regeneratingIds,
    Set<String>? loggingIds,
  }) {
    return TodayState(
      loading: loading ?? this.loading,
      dashboard: dashboard ?? this.dashboard,
      usage: usage ?? this.usage,
      error: error ?? this.error,
      regeneratingIds: regeneratingIds ?? this.regeneratingIds,
      loggingIds: loggingIds ?? this.loggingIds,
    );
  }
}

class TodayController extends StateNotifier<TodayState> {
  TodayController(this._service) : super(const TodayState());

  final TodayService _service;

  /// Loads the dashboard (required) and weekly usage (best-effort) in parallel.
  /// Keeps any previously loaded data visible while refreshing; resets the
  /// transient per-card busy sets (a full reload supersedes them).
  Future<void> load() async {
    state = TodayState(
      loading: true,
      dashboard: state.dashboard,
      usage: state.usage,
    );

    // Start both concurrently; usage carries its own catch so a failure there
    // never surfaces as an unhandled error if the dashboard throws first.
    final dashboardFuture = _service.getDashboard();
    final Future<CurrentWeekUsage?> usageFuture = _service
        .getCurrentWeekUsage()
        .then<CurrentWeekUsage?>((u) => u)
        .catchError((_) => null);

    try {
      final dashboard = await dashboardFuture;
      final usage = await usageFuture;
      state = TodayState(dashboard: dashboard, usage: usage);
    } on ApiException catch (e) {
      state = TodayState(error: e, dashboard: state.dashboard, usage: state.usage);
    }
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
  return TodayController(ref.read(todayServiceProvider));
});
