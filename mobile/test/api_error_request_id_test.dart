import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/models/api_error.dart';

RequestOptions _options() => RequestOptions(path: '/api/v1/users/me')
  ..headers['X-Request-ID'] = 'client-mint-1';

void main() {
  test('server echo of X-Request-ID wins and rides in toString', () {
    final err = DioException(
      requestOptions: _options(),
      response: Response(
        requestOptions: _options(),
        statusCode: 401,
        data: {
          'detail': {'code': 'invalid_credentials', 'message': 'Nope'}
        },
        headers: Headers.fromMap({
          'x-request-id': ['server-echo-1']
        }),
      ),
    );
    final e = ApiException.fromDio(err);
    expect(e.requestId, 'server-echo-1');
    expect(e.toString(), contains('[rid server-echo-1]'));
    expect(e.code, 'invalid_credentials');
  });

  test('timeout keeps the client-minted id (server never answered)', () {
    final e = ApiException.fromDio(DioException(
      requestOptions: _options(),
      type: DioExceptionType.connectionTimeout,
    ));
    expect(e.code, 'timeout');
    expect(e.requestId, 'client-mint-1');
  });

  test('absent ids leave toString unchanged', () {
    final e = ApiException.fromDio(DioException(
      requestOptions: RequestOptions(path: '/x'),
      type: DioExceptionType.connectionError,
    ));
    expect(e.requestId, isNull);
    expect(e.toString(), isNot(contains('[rid')));
  });
}
