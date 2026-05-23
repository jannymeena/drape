import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/api_error.dart';

/// Locks the SP2 gotcha: the usage (429) and AI-gateway (502) errors key their
/// slug as `error`, not `code` (shape captured live from
/// `POST /outfits/{id}/mix-and-match`). `ApiException.fromDio` must surface
/// that as `code` so the UI can branch on `limit_reached`.
void main() {
  DioException dioErr(int status, Object? data) {
    final req = RequestOptions(path: '/x');
    return DioException(
      requestOptions: req,
      response: Response(requestOptions: req, statusCode: status, data: data),
      type: DioExceptionType.badResponse,
    );
  }

  test('429 limit_reached (keyed as `error`) maps to code=limit_reached', () {
    final e = ApiException.fromDio(dioErr(429, {
      'detail': {
        'error': 'limit_reached',
        'resource': 'outfits',
        'used': 21,
        'limit': 21,
        'resets_at': '2026-05-25T05:00:00+00:00',
        'message': 'Weekly outfits limit reached (21/21).',
      }
    }));
    expect(e.code, 'limit_reached');
    expect(e.statusCode, 429);
    expect(e.message, contains('Weekly outfits limit reached'));
  });

  test('502 ai_call_failed (keyed as `error`) is surfaced', () {
    final e = ApiException.fromDio(dioErr(502, {
      'detail': {'error': 'ai_call_failed', 'message': 'The stylist hiccuped.'}
    }));
    expect(e.code, 'ai_call_failed');
    expect(e.statusCode, 502);
  });

  test('our own {code,message} errors still take precedence', () {
    final e = ApiException.fromDio(dioErr(401, {
      'detail': {'code': 'invalid_credentials', 'message': 'Wrong password.'}
    }));
    expect(e.code, 'invalid_credentials');
  });
}
