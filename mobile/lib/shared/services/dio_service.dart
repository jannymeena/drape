import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../config/api_config.dart';
import 'session_store.dart';
import 'storage_service.dart';

/// Builds the single shared [Dio] instance for the whole app.
///
/// Interceptors (per `MOBILE_PLAN.md` §"Phase D"):
/// - [_AuthInterceptor]    — attaches the bearer access token from storage.
/// - [_RefreshInterceptor] — on 401, silently refreshes the (short-lived)
///   access token via the rotating refresh token and retries the request.
/// - [_LoggingInterceptor] — structlog-style request/response/error in debug.
///
/// The refresh interceptor is added *after* auth so it sees the 401 with the
/// (now-stale) bearer that auth attached, and *before* logging so a recovered
/// request's retry is what gets logged.
Dio buildDio(StorageService storage) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.add(_RequestIdInterceptor());
  dio.interceptors.add(_AuthInterceptor(storage));
  dio.interceptors.add(_RefreshInterceptor(storage: storage, client: dio));
  if (kDebugMode) {
    dio.interceptors.add(_LoggingInterceptor());
  }

  return dio;
}

/// Client-minted correlation id, one per request. The backend middleware
/// accepts the X-Request-ID header and stamps it on every server log line
/// for that request, so an id captured from a client error joins both sides
/// of the same call — even for timeouts, where only the server log exists.
class _RequestIdInterceptor extends Interceptor {
  static const _uuid = Uuid();

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers['X-Request-ID'] = _uuid.v4();
    handler.next(options);
  }
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

/// Silent token refresh on `401`.
///
/// The access token is short-lived; the refresh token lives ~30 days and
/// rotates (single-use) on each refresh. When an authed call comes back `401`,
/// this interceptor calls `POST /auth/refresh-token` once, stores the new pair,
/// and replays the original request with the fresh access token — so the user
/// stays signed in until the *refresh* token expires, not the access token.
///
/// Extends [QueuedInterceptor] so concurrent 401s are handled one at a time:
/// the first triggers the refresh; the rest see the already-rotated token in
/// storage and simply retry (no duplicate refresh against a now-revoked token).
///
/// The refresh call and the replayed request both go through a **bare** Dio
/// ([_bare]) with no interceptors — never back through this queued interceptor.
/// That's deliberate: re-entering the error queue from inside an error handler
/// (e.g. when the refresh itself 401s) would deadlock the queue. A request is
/// retried at most once (guarded by `extra['__refresh_retried__']`). When
/// refresh itself fails (refresh token expired/revoked), local session state is
/// cleared so the router falls back to Welcome.
class _RefreshInterceptor extends QueuedInterceptor {
  _RefreshInterceptor({required this.storage, required this.client});

  final StorageService storage;
  final Dio client;

  static const _retriedFlag = '__refresh_retried__';

  /// Interceptor-free client for the refresh POST and the replayed request, so
  /// neither re-enters this interceptor's (occupied) error queue. Shares
  /// [client]'s adapter — the real one in production, a fake in tests.
  late final Dio _bare = Dio(
    BaseOptions(
      baseUrl: client.options.baseUrl,
      connectTimeout: client.options.connectTimeout,
      receiveTimeout: client.options.receiveTimeout,
      contentType: Headers.jsonContentType,
    ),
  );

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final is401 = err.response?.statusCode == 401;
    final isAuthRoute = options.path.startsWith('/auth/');
    final alreadyRetried = options.extra[_retriedFlag] == true;

    if (!is401 || isAuthRoute || alreadyRetried) {
      return handler.next(err);
    }

    // A concurrent 401 may have already refreshed the token while this one was
    // queued — if storage now holds a different access token, just retry.
    final usedAuth = options.headers['Authorization'] as String?;
    final storedAccess = await storage.getAccessToken();
    if (storedAccess != null && usedAuth != 'Bearer $storedAccess') {
      return _retry(options, storedAccess, handler);
    }

    final refreshToken = await storage.getRefreshToken();
    if (refreshToken == null) {
      await _onRefreshFailed();
      return handler.next(err);
    }

    try {
      final tokens = await _refresh(refreshToken);
      await storage.saveTokens(
        accessToken: tokens.access,
        refreshToken: tokens.refresh,
      );
      return _retry(options, tokens.access, handler);
    } catch (_) {
      await _onRefreshFailed();
      return handler.next(err);
    }
  }

  Future<({String access, String refresh})> _refresh(String refreshToken) async {
    _bare.httpClientAdapter = client.httpClientAdapter;
    final resp = await _bare.post<Map<String, dynamic>>(
      '/auth/refresh-token',
      data: {'refresh_token': refreshToken},
    );
    final data = resp.data!;
    return (
      access: data['access_token'] as String,
      refresh: data['refresh_token'] as String,
    );
  }

  Future<void> _retry(
    RequestOptions options,
    String accessToken,
    ErrorInterceptorHandler handler,
  ) async {
    options.headers['Authorization'] = 'Bearer $accessToken';
    options.extra[_retriedFlag] = true;
    _bare.httpClientAdapter = client.httpClientAdapter;
    try {
      final response = await _bare.fetch<dynamic>(options);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  Future<void> _onRefreshFailed() async {
    await storage.clearAll();
    await SessionStore.clear();
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
      '— ${err.response?.data ?? err.message} '
      '(rid ${err.requestOptions.headers['X-Request-ID']})',
    );
    handler.next(err);
  }
}
