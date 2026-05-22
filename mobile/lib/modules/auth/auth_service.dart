import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/auth_response.dart';
import 'models/current_user.dart';

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

  /// `POST /auth/signup` with `auth_method: "email"`.
  ///
  /// [displayName] is required by the backend; the client derives it from the
  /// email local-part (the signup screen collects no name). Consent is implied
  /// by the screen copy, so both `agreed_to_*` flags are sent `true`.
  ///
  /// Throws [ApiException] on a duplicate email (400 `email_already_exists`),
  /// validation (422), or transport errors.
  Future<AuthResponse> signupWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {
          'auth_method': 'email',
          'email': email,
          'password': password,
          'display_name': displayName,
          'agreed_to_terms': true,
          'agreed_to_privacy': true,
        },
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/forgot-password`. Always succeeds (202) regardless of whether
  /// the address has an account — the backend never confirms existence (no
  /// enumeration). Throws [ApiException] only on validation/transport errors.
  Future<void> requestPasswordReset({required String email}) async {
    try {
      await _dio.post<void>('/auth/forgot-password', data: {'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/logout` — revokes the refresh token server-side. Best-effort
  /// from the caller's view: local sign-out proceeds even if this throws.
  Future<void> logout({required String refreshToken}) async {
    try {
      await _dio.post<void>('/auth/logout', data: {'refresh_token': refreshToken});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /users/me` — the signed-in user's identity (bearer attached by the
  /// auth interceptor). Throws [ApiException] (401 on an expired/invalid token).
  Future<CurrentUser> fetchCurrentUser() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/me');
      return CurrentUser.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.read(dioProvider));
});
