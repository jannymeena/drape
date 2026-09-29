import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../wardrobe/image_pick.dart';
import 'models/shop.dart';

/// Backend `/shop/*` endpoints (items 7a–7e). 429s carry the paywall `plans`
/// payload; callers surface them via the shared limit handling.
class ShopService {
  ShopService(this._dio);

  final Dio _dio;

  // Last feed + its ETag. The backend answers an unchanged catalog with an
  // empty 304, so revisits (and a feed prefetched during onboarding) don't
  // re-download the product list.
  ShopFeed? _feed;
  String? _feedEtag;

  /// `GET /shop/feed`, cache-validated with If-None-Match.
  Future<ShopFeed> getFeed() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>(
        '/shop/feed',
        options: Options(
          headers: {if (_feed != null && _feedEtag != null) 'If-None-Match': _feedEtag},
          validateStatus: (s) => s != null && ((s >= 200 && s < 300) || s == 304),
        ),
      );
      final cached = _feed;
      if (r.statusCode == 304 && cached != null) return cached;
      final feed = ShopFeed.fromJson(r.data!);
      _feed = feed;
      _feedEtag = r.headers.value('etag');
      return feed;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Warms the feed cache (onboarding prefetch). Best-effort.
  Future<void> prefetchFeed() async {
    try {
      await getFeed();
    } on ApiException {
      // The Shop tab loads it normally.
    }
  }

  /// `POST /shop/advisor/ask` — one turn; 429 when the weekly limit is hit.
  Future<AdvisorConversation> advisorAsk(
    String question, {
    String? conversationId,
  }) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/shop/advisor/ask',
        data: {
          'question': question,
          'conversation_id': ?conversationId,
        },
      );
      return AdvisorConversation.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /shop/advisor/history`.
  Future<List<AdvisorConversation>> advisorHistory() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/shop/advisor/history');
      return (r.data!['conversations'] as List<dynamic>)
          .map((e) => AdvisorConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /shop/buy-check` — multipart image → verdict; 429 on the 5/week cap.
  Future<BuyDontBuyVerdict> buyCheck(
    PickedImage image, {
    String? productName,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          image.bytes,
          filename: image.filename,
          contentType: DioMediaType.parse(image.mimeType),
        ),
        'product_name': ?productName,
      });
      final r =
          await _dio.post<Map<String, dynamic>>('/shop/buy-check', data: form);
      return BuyDontBuyVerdict.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /shop/buy-check/history` — recent checks (newest first).
  Future<List<BuyDontBuyVerdict>> buyCheckHistory() async {
    try {
      final r =
          await _dio.get<Map<String, dynamic>>('/shop/buy-check/history');
      return (r.data!['checks'] as List<dynamic>)
          .map((e) => BuyDontBuyVerdict.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /shop/gap-analysis` — free tier gets the teaser shape.
  Future<GapAnalysis> gapAnalysis() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/shop/gap-analysis');
      return GapAnalysis.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /shop/wishlist`.
  Future<List<WishlistEntry>> getWishlist() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/shop/wishlist');
      return (r.data!['items'] as List<dynamic>)
          .map((e) => WishlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /shop/wishlist` — idempotent; returns the refreshed list.
  Future<List<WishlistEntry>> addToWishlist(String productId) async {
    try {
      final r = await _dio.post<Map<String, dynamic>>(
        '/shop/wishlist',
        data: {'product_id': productId},
      );
      return (r.data!['items'] as List<dynamic>)
          .map((e) => WishlistEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /shop/wishlist/{productId}`.
  Future<void> removeFromWishlist(String productId) async {
    try {
      await _dio.delete<void>('/shop/wishlist/$productId');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final shopServiceProvider = Provider<ShopService>((ref) {
  // User-scoped: the cached feed is filtered to the user's genders.
  ref.watch(sessionEpochProvider);
  return ShopService(ref.read(dioProvider));
});

final shopFeedProvider = FutureProvider.autoDispose<ShopFeed>((ref) {
  return ref.read(shopServiceProvider).getFeed();
});

final gapAnalysisProvider = FutureProvider.autoDispose<GapAnalysis>((ref) {
  return ref.read(shopServiceProvider).gapAnalysis();
});

final advisorHistoryProvider =
    FutureProvider.autoDispose<List<AdvisorConversation>>((ref) {
  return ref.read(shopServiceProvider).advisorHistory();
});

final wishlistProvider =
    FutureProvider.autoDispose<List<WishlistEntry>>((ref) {
  return ref.read(shopServiceProvider).getWishlist();
});

final buyCheckHistoryProvider =
    FutureProvider.autoDispose<List<BuyDontBuyVerdict>>((ref) {
  return ref.read(shopServiceProvider).buyCheckHistory();
});
