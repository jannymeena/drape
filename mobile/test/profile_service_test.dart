import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/profile/profile_service.dart';
import 'package:mobile/shared/models/api_error.dart';

/// `ProfileService.updateProfile` (`PATCH /users/{id}`): only changed fields go
/// on the wire (backend uses `exclude_unset`), the response parses into a
/// `CurrentUser`, and a non-2xx (e.g. an email already in use) becomes a typed
/// `ApiException`.
void main() {
  final jsonHeaders = {
    Headers.contentTypeHeader: [Headers.jsonContentType],
  };

  ResponseBody userBody(String name, String email) => ResponseBody.fromString(
        '{"id":"u1","email":"$email","display_name":"$name",'
        '"role":"customer","created_at":"2026-01-01T00:00:00.000Z"}',
        200,
        headers: jsonHeaders,
      );

  test('sends both changed fields and parses the returned user', () async {
    final adapter = _CaptureAdapter(userBody('New Name', 'new@example.com'));
    final svc = ProfileService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    final user = await svc.updateProfile(
      userId: 'u1',
      displayName: 'New Name',
      email: 'new@example.com',
    );

    expect(adapter.lastMethod, 'PATCH');
    expect(adapter.lastPath, '/users/u1');
    expect(adapter.lastBody,
        {'display_name': 'New Name', 'email': 'new@example.com'});
    expect(user.displayName, 'New Name');
    expect(user.email, 'new@example.com');
  });

  test('omits the null field (display_name only)', () async {
    final adapter = _CaptureAdapter(userBody('Only Name', 'same@example.com'));
    final svc = ProfileService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    await svc.updateProfile(userId: 'u1', displayName: 'Only Name');

    expect(adapter.lastBody, {'display_name': 'Only Name'});
    expect(adapter.lastBody!.containsKey('email'), isFalse);
  });

  test('maps a non-2xx response to ApiException', () async {
    final adapter = _CaptureAdapter(ResponseBody.fromString(
      '{"detail":{"code":"email_in_use","message":"Email already in use."}}',
      409,
      headers: jsonHeaders,
    ));
    final svc = ProfileService(Dio(BaseOptions(baseUrl: 'http://x'))
      ..httpClientAdapter = adapter);

    await expectLater(
      svc.updateProfile(userId: 'u1', email: 'dupe@example.com'),
      throwsA(isA<ApiException>()),
    );
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
      lastBody =
          body.isEmpty ? {} : jsonDecode(body) as Map<String, dynamic>;
    }
    return _response;
  }

  @override
  void close({bool force = false}) {}
}
