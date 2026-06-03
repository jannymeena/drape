import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/log_outfit_result.dart';
import 'models/outfit.dart';
import 'models/outfit_history.dart';
import 'models/outfit_reasoning.dart';
import 'models/today_dashboard.dart';
import 'models/usage.dart';

/// Talks to the backend Today / outfits / usage endpoints. Like the other
/// services, every [DioException] becomes a typed [ApiException]; the bearer is
/// attached by the auth interceptor.
///
/// Sub-phase 1 covers the read path (dashboard + weekly usage). Sub-phase 2
/// adds the outfit actions (regenerate / log-as-worn). Sub-phase 3 adds the
/// read-only history + reasoning detail + mix-and-match swaps.
class TodayService {
  TodayService(this._dio);

  final Dio _dio;

  /// `GET /today/dashboard` — composite home payload. The backend lazily
  /// generates the day's outfits via the AI provider if none exist yet, so this
  /// call can take a few seconds on first load. May 400 (`no_wardrobe`) for a
  /// user with no items.
  Future<TodayDashboard> getDashboard() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/today/dashboard');
      return TodayDashboard.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /usage/current-week` — weekly free-tier counters for the usage banner.
  Future<CurrentWeekUsage> getCurrentWeekUsage() async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/usage/current-week');
      return CurrentWeekUsage.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /outfits/{id}/regenerate` — AI-generates a fresh outfit (a new row,
  /// different items) for the same occasion. Counts against the weekly outfit
  /// limit, so this can throw `ApiException(code: 'limit_reached', 429)`; it can
  /// also 502 if the AI provider fails (`ai_call_failed` / `parse_failed`).
  Future<Outfit> regenerateOutfit(String outfitId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/outfits/$outfitId/regenerate',
      );
      return Outfit.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /outfits/{id}/log` — marks the outfit worn today. Returns the
  /// server-authored toast + streak counters (not the outfit), and is *not*
  /// usage-limited. Idempotent server-side for a second log on the same day.
  Future<LogOutfitResult> logOutfitWorn(String outfitId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/outfits/$outfitId/log',
      );
      return LogOutfitResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /outfits/{id}/mix-and-match` — applies `{old→new}` item swaps and
  /// returns the new lineup + recomputed compatibility (deterministic, no AI
  /// call). Counts against the weekly `mix_and_match` limit (429
  /// `limit_reached`); a swap referencing an item not owned / not in the outfit
  /// 400s (`invalid_swap`).
  Future<({List<OutfitItem> items, int score})> mixAndMatch(
    String outfitId,
    List<({String oldItemId, String newItemId})> swaps,
  ) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/outfits/$outfitId/mix-and-match',
        data: {
          'swapped_items': [
            for (final s in swaps)
              {'old_item_id': s.oldItemId, 'new_item_id': s.newItemId},
          ],
        },
      );
      final data = response.data!;
      final items = (data['items'] as List<dynamic>)
          .map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
          .toList();
      return (items: items, score: data['compatibility_score'] as int);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /outfits/history` — logged outfits (newest first) for the history
  /// screen, plus the streak summary. [filter] is one of the backend
  /// `HistoryFilter` literals (`this_week` / `this_month` / `last_3_months` /
  /// `all`).
  Future<OutfitHistory> getHistory({String filter = 'all'}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/outfits/history',
        queryParameters: {'filter': filter},
      );
      return OutfitHistory.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /outfits/{id}/reasoning` — the long-form "why this works" narrative,
  /// per-item rationales, and the compatibility band for one outfit. 404s
  /// (`not_found`) if the outfit isn't owned by the caller.
  Future<OutfitReasoning> getReasoning(String outfitId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/outfits/$outfitId/reasoning',
      );
      return OutfitReasoning.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final todayServiceProvider = Provider<TodayService>((ref) {
  return TodayService(ref.read(dioProvider));
});

/// History + reasoning are read-once flows (no mutation), so a
/// [FutureProvider.family] is a better fit than the mutable [TodayController]:
/// it gives loading/error/data via [AsyncValue] for free, and switching the
/// history filter or opening a different outfit just watches a different key.

/// Keyed by the `HistoryFilter` literal (`this_week` / `all` / …).
final outfitHistoryProvider =
    FutureProvider.family<OutfitHistory, String>((ref, filter) {
  return ref.read(todayServiceProvider).getHistory(filter: filter);
});

/// Keyed by outfit id.
final outfitReasoningProvider =
    FutureProvider.family<OutfitReasoning, String>((ref, outfitId) {
  return ref.read(todayServiceProvider).getReasoning(outfitId);
});
