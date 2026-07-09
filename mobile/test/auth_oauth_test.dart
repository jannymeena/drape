import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/auth/auth_service.dart';
import 'package:mobile/modules/auth/widgets/oauth_buttons.dart';
import 'package:mobile/shared/config/feature_flags.dart';
import 'package:mobile/shared/models/api_error.dart';

/// OAuth sign-in (MOBILE_CHANGES P2): the wire shape of
/// `AuthService.loginWithOAuth/signupWithOAuth` against the backend contract
/// (`app/schemas/auth.py`), backend rejections surfacing as typed
/// [ApiException]s, and the feature-switched [OAuthButtons] collapsing when
/// nothing is enabled (this test binary builds with no dart-defines, so both
/// flags are off — the backend-mirrored `DISABLED_FEATURES` default).
void main() {
  final jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  ResponseBody authBody() => ResponseBody.fromString(
        '{"user_id":"u1","email":"o@example.com","access_token":"at",'
        '"refresh_token":"rt","token_type":"bearer",'
        '"onboarding_completed":false,"next_step":"age_range"}',
        200,
        headers: jsonHeaders,
      );

  test('google login sends auth_method + google_id_token and parses', () async {
    final adapter = _CaptureAdapter(authBody());
    final svc = AuthService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    final response =
        await svc.loginWithOAuth(provider: 'google', idToken: 'g-token');

    expect(adapter.lastMethod, 'POST');
    expect(adapter.lastPath, '/auth/login');
    expect(adapter.lastBody, {
      'auth_method': 'google',
      'google_id_token': 'g-token',
    });
    expect(response.nextStep, 'age_range');
  });

  test('apple signup sends apple_id_token + both consent flags', () async {
    final adapter = _CaptureAdapter(authBody());
    final svc = AuthService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    await svc.signupWithOAuth(provider: 'apple', idToken: 'a-token');

    expect(adapter.lastPath, '/auth/signup');
    expect(adapter.lastBody, {
      'auth_method': 'apple',
      'apple_id_token': 'a-token',
      'agreed_to_terms': true,
      'agreed_to_privacy': true,
    });
  });

  test('a rejected token surfaces as ApiException with the backend code',
      () async {
    final adapter = _CaptureAdapter(ResponseBody.fromString(
      '{"detail":{"code":"oauth_invalid_token",'
      '"message":"Token verification failed"}}',
      401,
      headers: jsonHeaders,
    ));
    final svc = AuthService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    await expectLater(
      svc.loginWithOAuth(provider: 'google', idToken: 'bad'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'oauth_invalid_token')),
    );
  });

  testWidgets('OAuthButtons collapses entirely when both flags are off',
      (tester) async {
    // Guard the premise: no dart-defines in the test binary, and the test
    // host is not iOS, so both switches resolve off.
    expect(FeatureFlags.appleLogin, isFalse);
    expect(FeatureFlags.googleLogin, isFalse);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: OAuthButtons(onApple: () {}, onGoogle: () {}),
      ),
    ));

    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.text('or'), findsNothing);
  });
}

class _CaptureAdapter implements HttpClientAdapter {
  _CaptureAdapter(this._response);

  final ResponseBody _response;
  String? lastPath;
  String? lastMethod;
  Map<String, dynamic>? lastBody;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastPath = options.path;
    lastMethod = options.method;
    if (requestStream != null) {
      final chunks = await requestStream.toList();
      final bytes = chunks.expand((c) => c).toList();
      final body = utf8.decode(bytes);
      lastBody = body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
    }
    return _response;
  }

  @override
  void close({bool force = false}) {}
}
