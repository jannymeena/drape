import 'package:dio/dio.dart';

/// Typed wrapper over a failed backend call.
///
/// The backend raises `HTTPException(detail={"code": ..., "message": ...})`
/// (see `app/api/routes/auth/login.py`), so 4xx bodies look like
/// `{"detail": {"code": "invalid_credentials", "message": "..."}}`.
/// FastAPI request-validation (422) instead returns `{"detail": [ {...} ]}`.
/// Both shapes — plus transport failures (no server, timeout) — collapse here
/// into a stable `code` + a human [userMessage].
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
  });

  final String code;
  final String message;
  final int? statusCode;

  /// Correlation id of the failed call — the client-minted X-Request-ID (the
  /// server echoes the same value and logs every line under it). Rides in
  /// [toString] so crash reports and debug logs can be joined with the exact
  /// backend log lines.
  final String? requestId;

  factory ApiException.fromDio(DioException error) {
    final response = error.response;
    // Prefer the server's echo; fall back to the sent header, which exists
    // even when the server never answered (timeout) but may have logged it.
    final requestId = response?.headers.value('x-request-id') ??
        error.requestOptions.headers['X-Request-ID'] as String?;

    // Transport-level failures never reach the server.
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException(
          code: 'timeout',
          message: 'The server took too long to respond. Please try again.',
          requestId: requestId,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'network',
          message:
              "Can't reach Zoura. Check your connection and that the server is running.",
          requestId: requestId,
        );
      default:
        break;
    }

    final status = response?.statusCode;
    final detail = (response?.data is Map) ? (response!.data as Map)['detail'] : null;

    // Our own HTTPException shape: detail is a {code, message} object. The
    // usage (429) and AI-gateway (502) errors key the slug as `error` instead
    // of `code` (e.g. {"error": "limit_reached", ...}), so fall back to that.
    if (detail is Map) {
      return ApiException(
        code: (detail['code'] as String?) ??
            (detail['error'] as String?) ??
            'error',
        message: (detail['message'] as String?) ?? _statusFallback(status),
        statusCode: status,
        requestId: requestId,
      );
    }

    // FastAPI 422 validation: detail is a list of error objects.
    if (status == 422) {
      return ApiException(
        code: 'validation_error',
        message: 'Please check your details and try again.',
        statusCode: status,
        requestId: requestId,
      );
    }

    return ApiException(
      code: 'error',
      message: detail is String ? detail : _statusFallback(status),
      statusCode: status,
      requestId: requestId,
    );
  }

  static String _statusFallback(int? status) {
    if (status != null && status >= 500) {
      return 'Something went wrong on our end. Please try again shortly.';
    }
    return 'Something went wrong. Please try again.';
  }

  @override
  String toString() =>
      'ApiException($code, $statusCode): $message'
      '${requestId != null ? ' [rid $requestId]' : ''}';
}
