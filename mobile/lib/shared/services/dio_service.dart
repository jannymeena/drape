import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/api_config.dart';
import 'storage_service.dart';

/// Builds the single shared [Dio] instance for the whole app.
///
/// Interceptors (per `MOBILE_PLAN.md` §"Phase D"):
/// - [_AuthInterceptor]    — attaches the bearer access token from storage.
/// - [_LoggingInterceptor] — structlog-style request/response/error in debug.
///
/// NOT yet wired: the RefreshInterceptor (queue concurrent 401s → one
/// `POST /auth/refresh-token` → retry). It needs the refresh endpoint + a
/// request queue; it lands when the rest of Phase D does. Until then an expired
/// access token surfaces as a 401 the caller handles (login simply re-auths).
Dio buildDio(StorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(_AuthInterceptor(storage));
  if (kDebugMode) {
    dio.interceptors.add(_LoggingInterceptor());
  }

  return dio;
}

class _AuthInterceptor extends Interceptor {
  _AuthInterceptor(this._storage);

  final StorageService _storage;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Auth endpoints don't need (and shouldn't carry) a stale bearer token.
    final isAuthRoute = options.path.startsWith('/auth/');
    if (!isAuthRoute) {
      final token = await _storage.getAccessToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }
}

class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('→ ${options.method} ${options.uri}');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint(
      '← ${response.statusCode} ${response.requestOptions.method} '
      '${response.requestOptions.uri}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint(
      '✗ ${err.response?.statusCode ?? err.type.name} '
      '${err.requestOptions.method} ${err.requestOptions.uri} '
      '— ${err.response?.data ?? err.message}',
    );
    handler.next(err);
  }
}
