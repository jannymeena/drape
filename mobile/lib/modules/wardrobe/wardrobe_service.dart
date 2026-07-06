import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../today/today_service.dart';
import 'image_pick.dart';
import 'models/scan_detection.dart';
import 'models/wardrobe_analytics.dart';
import 'models/wardrobe_item.dart';
import 'models/wardrobe_mutations.dart';

/// Talks to the backend `/wardrobe` endpoints. Every [DioException] becomes a
/// typed [ApiException]; the bearer is attached by the auth interceptor.
///
/// Sub-phase 1 covers the read path (list + item detail). SP2 adds the
/// mutations (create / edit / delete / log-worn / favorite). SP3 adds AI
/// scanning + image upload (multipart). SP4 adds the analytics reports.
class WardrobeService {
  WardrobeService(this._dio);

  final Dio _dio;

  /// `GET /wardrobe` — the item grid. [category] / [isFavorite] / [isStarter]
  /// are exact-match server filters (omit for "all"); [limit] (≤200) / [offset]
  /// page the result. There is no text-search param — name search is done
  /// client-side over the loaded page.
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final params = <String, dynamic>{'limit': limit, 'offset': offset};
      if (category != null) params['category'] = category;
      if (isFavorite != null) params['is_favorite'] = isFavorite;
      if (isStarter != null) params['is_starter_wardrobe'] = isStarter;
      final response = await _dio.get<Map<String, dynamic>>(
        '/wardrobe',
        queryParameters: params,
      );
      return WardrobeListResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /wardrobe/items/{id}` — full item detail. 404s (`not_found`) if the
  /// item isn't owned by the caller.
  Future<WardrobeItem> getItem(String itemId) async {
    try {
      final response =
          await _dio.get<Map<String, dynamic>>('/wardrobe/items/$itemId');
      return WardrobeItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/items` — manual create (201). Can throw
  /// `ApiException(code: 'limit_reached', 429)` when the free-tier 30-item cap
  /// is hit (the slug is keyed as `error`; `ApiException.fromDio` surfaces it).
  Future<WardrobeItem> createItem(WardrobeItemInput input) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/items',
        data: input.toJson(),
      );
      return WardrobeItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /wardrobe/items/{id}` — partial update; only the non-null fields in
  /// [input] are sent. Returns the full updated item.
  Future<WardrobeItem> updateItem(String itemId, WardrobeItemInput input) async {
    try {
      final response = await _dio.patch<Map<String, dynamic>>(
        '/wardrobe/items/$itemId',
        data: input.toJson(),
      );
      return WardrobeItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /wardrobe/items/{id}` — hard delete (204).
  Future<void> deleteItem(String itemId) async {
    try {
      await _dio.delete<void>('/wardrobe/items/$itemId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/items/{id}/log-worn` — records a wear (defaults to today
  /// server-side). Idempotent for a second log the same day
  /// (`already_logged_today`). Not usage-limited.
  Future<LogWornResult> logWorn(String itemId, {DateTime? wornDate}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/items/$itemId/log-worn',
        data: {
          if (wornDate != null)
            'worn_date': '${wornDate.year}-'
                '${wornDate.month.toString().padLeft(2, '0')}-'
                '${wornDate.day.toString().padLeft(2, '0')}',
        },
      );
      return LogWornResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/items/{id}/toggle-favorite` — flips the favorite flag,
  /// returning the new state + timestamp.
  Future<ToggleFavoriteResult> toggleFavorite(String itemId) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/items/$itemId/toggle-favorite',
      );
      return ToggleFavoriteResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/scan-item` — AI-detects category/color/pattern/formality
  /// for a single image (does not persist). Throws
  /// `ApiException(code: 'low_confidence', 400)` when the model isn't confident
  /// enough to suggest a detection, or 502 (`parse_failed`/`ai_call_failed`) on
  /// an upstream failure.
  Future<ScanItemResult> scanItem(PickedImage image) async {
    try {
      final form = FormData.fromMap({'file': _multipart(image)});
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/scan-item',
        data: form,
      );
      return ScanItemResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/batch-upload` — AI-detects up to 12 images at once (does
  /// not persist). Per-image failures are folded into the response rows rather
  /// than failing the whole call; a >12 batch 400s.
  Future<BatchUploadResult> batchUpload(List<PickedImage> images) async {
    try {
      final form = FormData.fromMap({
        'files': [for (final image in images) _multipart(image)],
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/batch-upload',
        data: form,
      );
      return BatchUploadResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /wardrobe/items/{id}/images` — attaches photos to an existing item
  /// (max 4 server-side). Returns the updated item. 415 on an unsupported type,
  /// 413 if a file exceeds the 8 MiB cap.
  Future<WardrobeItem> addImages(String itemId, List<PickedImage> images) async {
    try {
      final form = FormData.fromMap({
        'files': [for (final image in images) _multipart(image)],
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/wardrobe/items/$itemId/images',
        data: form,
      );
      return WardrobeItem.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  MultipartFile _multipart(PickedImage image) => MultipartFile.fromBytes(
        image.bytes,
        filename: image.filename,
        contentType: DioMediaType.parse(image.mimeType),
      );

  // ── analytics (SP4) ────────────────────────────────────────────────────

  /// `GET /wardrobe/analytics/cost-per-wear` (free) — per-item + per-category
  /// cost-per-wear roll-up.
  Future<CostPerWearReport> costPerWear() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/wardrobe/analytics/cost-per-wear');
      return CostPerWearReport.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /wardrobe/analytics/utilization-score` (free) — % of items worn in
  /// the last 30 days.
  Future<UtilizationScore> utilizationScore() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/wardrobe/analytics/utilization-score');
      return UtilizationScore.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /wardrobe/analytics/weekly-report` (free) — the weekly recap teaser.
  Future<WeeklyReport> weeklyReport() async {
    try {
      final response = await _dio
          .get<Map<String, dynamic>>('/wardrobe/analytics/weekly-report');
      return WeeklyReport.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /wardrobe/analytics/intelligence-report` (Pro). Throws
  /// `ApiException(code: 'pro_required', 402)` for free users (the slug is
  /// keyed as `error`; `ApiException.fromDio` surfaces it as `code`).
  Future<IntelligenceReport> intelligenceReport() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
          '/wardrobe/analytics/intelligence-report');
      return IntelligenceReport.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final wardrobeServiceProvider = Provider<WardrobeService>((ref) {
  return WardrobeService(ref.read(dioProvider));
});

// Every provider below caches user-scoped data for the app's lifetime, so
// each watches the session epoch — rebuilt on login/logout (see
// session_epoch.dart).

/// Read-once item detail, keyed by id (same pattern as the Today reasoning
/// provider). `AsyncValue` gives the detail screen loading/error/data for free.
final wardrobeItemProvider =
    FutureProvider.family<WardrobeItem, String>((ref, itemId) {
  ref.watch(sessionEpochProvider);
  return ref.read(wardrobeServiceProvider).getItem(itemId);
});

/// Free-tier capacity for the warning banner. Composes the real (non-starter)
/// item count with the subscription tier — the tier comes from
/// `/usage/current-week` (the only endpoint exposing it today), defaulting to
/// free if that read fails. Invalidate after create/delete to refresh.
final wardrobeCapacityProvider = FutureProvider<WardrobeCapacity>((ref) async {
  ref.watch(sessionEpochProvider);
  final service = ref.read(wardrobeServiceProvider);
  final real = await service.getItems(isStarter: false, limit: 1);
  var isPro = false;
  try {
    final usage = await ref.read(todayServiceProvider).getCurrentWeekUsage();
    isPro = usage.isPro;
  } on ApiException {
    // Banner is a warning, not a gate — fall back to free.
  }
  return WardrobeCapacity(used: real.total, isPro: isPro);
});

// Read-once analytics providers (same pattern as the detail/reasoning reads).
final costPerWearProvider = FutureProvider<CostPerWearReport>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.read(wardrobeServiceProvider).costPerWear();
});

final utilizationScoreProvider = FutureProvider<UtilizationScore>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.read(wardrobeServiceProvider).utilizationScore();
});

final weeklyReportProvider = FutureProvider<WeeklyReport>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.read(wardrobeServiceProvider).weeklyReport();
});

final intelligenceReportProvider = FutureProvider<IntelligenceReport>((ref) {
  ref.watch(sessionEpochProvider);
  return ref.read(wardrobeServiceProvider).intelligenceReport();
});
