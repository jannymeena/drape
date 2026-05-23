import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/wardrobe_item.dart';

/// Talks to the backend `/wardrobe` endpoints. Every [DioException] becomes a
/// typed [ApiException]; the bearer is attached by the auth interceptor.
///
/// Sub-phase 1 covers the read path (list + item detail). Mutations (create /
/// edit / delete / log-worn / favorite) land in SP2, image upload + AI scanning
/// in SP3, and analytics in SP4.
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
}

final wardrobeServiceProvider = Provider<WardrobeService>((ref) {
  return WardrobeService(ref.read(dioProvider));
});

/// Read-once item detail, keyed by id (same pattern as the Today reasoning
/// provider). `AsyncValue` gives the detail screen loading/error/data for free.
final wardrobeItemProvider =
    FutureProvider.family<WardrobeItem, String>((ref, itemId) {
  return ref.read(wardrobeServiceProvider).getItem(itemId);
});
