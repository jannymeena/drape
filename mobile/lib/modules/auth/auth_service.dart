import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/auth_response.dart';

/// Talks to the backend `/auth/*` endpoints. Translates Dio failures into
/// typed [ApiException]s so the UI never sees a raw `DioException`.
class AuthService {
  AuthService(this._dio);

  final Dio _dio;

  /// `POST /auth/login` with `auth_method: "email"`.
  ///
  /// Throws [ApiException] on bad credentials (401 `invalid_credentials`),
  /// inactive account (403 `inactive`), validation (422), or transport errors.
  Future<AuthResponse> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'auth_method': 'email',
          'email': email,
          'password': password,
        },
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});
