import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mobile/shared/services/dio_service.dart';
import 'package:mobile/shared/services/session_store.dart';
import 'package:mobile/shared/services/storage_service.dart';

/// Exercises the silent-refresh-on-401 behavior of the Dio stack built by
/// [buildDio]: an expired access token is transparently refreshed via the
/// rotating refresh token, concurrent 401s share a single refresh, and a failed
/// refresh clears the session.
void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    SessionStore.state.value = false;
  });

  ResponseBody json(int status, String body) => ResponseBody.fromString(
        body,
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  const newPairBody =
      '{"user_id":"u1","email":"a@example.com","access_token":"new-access","refresh_token":"new-refresh","token_type":"bearer","onboarding_completed":true,"next_step":"today_dashboard"}';

  test('expired access token is refreshed and the request is retried', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'valid-refresh',
    });
    final storage = StorageService();
    final dio = buildDio(storage);
    final fake = _FakeAdapter(
      validAccess: 'new-access',
      onRefresh: () => json(200, newPairBody),
    );
    dio.httpClientAdapter = fake;

    final res = await dio.get<Map<String, dynamic>>('/users/me');

    expect(res.statusCode, 200);
    expect(res.data!['email'], 'a@example.com');
    // Refreshed exactly once; /users/me ran twice (initial 401 + retry).
    expect(fake.refreshCalls, 1);
    expect(fake.meCalls, 2);
    // The rotated pair was persisted.
    expect(await storage.getAccessToken(), 'new-access');
    expect(await storage.getRefreshToken(), 'new-refresh');
  });

  test('concurrent 401s trigger only a single refresh', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'valid-refresh',
    });
    final dio = buildDio(StorageService());
    final fake = _FakeAdapter(
      validAccess: 'new-access',
      onRefresh: () => json(200, newPairBody),
    );
    dio.httpClientAdapter = fake;

    final results = await Future.wait([
      dio.get<Map<String, dynamic>>('/users/me'),
      dio.get<Map<String, dynamic>>('/users/me'),
      dio.get<Map<String, dynamic>>('/users/me'),
    ]);

    expect(results.every((r) => r.statusCode == 200), isTrue);
    expect(fake.refreshCalls, 1); // single-flight: only one refresh
    expect(fake.meCalls, 6); // 3 initial 401s + 3 retries
  });

  test('failed refresh clears the session and surfaces the 401', () async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'expired-access',
      'refresh_token': 'expired-refresh',
    });
    SessionStore.state.value = true;
    final storage = StorageService();
    final dio = buildDio(storage);
    final fake = _FakeAdapter(
      validAccess: 'new-access',
      onRefresh: () => json(
        401,
        '{"detail":{"code":"invalid_refresh","message":"Refresh token is invalid or expired"}}',
      ),
    );
    dio.httpClientAdapter = fake;

    await expectLater(
      dio.get<Map<String, dynamic>>('/users/me'),
      throwsA(
        isA<DioException>().having(
          (e) => e.response?.statusCode,
          'statusCode',
          401,
        ),
      ),
    );

    expect(fake.refreshCalls, 1);
    expect(await storage.getAccessToken(), isNull); // tokens cleared
    expect(SessionStore.state.value, isFalse); // session flag cleared
  });
}

/// Minimal in-memory [HttpClientAdapter]: `/users/me` returns 401 unless the
/// bearer matches [validAccess]; `/auth/refresh-token` returns whatever
/// [onRefresh] yields. Counts calls so tests can assert refresh/retry behavior.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({required this.validAccess, required this.onRefresh});

  final String validAccess;
  final ResponseBody Function() onRefresh;

  int meCalls = 0;
  int refreshCalls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    switch (options.path) {
      case '/auth/refresh-token':
        refreshCalls++;
        return onRefresh();
      case '/users/me':
        meCalls++;
        final auth = options.headers['Authorization'];
        if (auth == 'Bearer $validAccess') {
          return ResponseBody.fromString(
            '{"id":"u1","email":"a@example.com","display_name":"a","role":"customer","created_at":"2026-01-01T00:00:00.000Z"}',
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        return ResponseBody.fromString(
          '{"detail":"Invalid or expired token"}',
          401,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      default:
        return ResponseBody.fromString('{"detail":"not found"}', 404, headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        });
    }
  }

  @override
  void close({bool force = false}) {}
}
