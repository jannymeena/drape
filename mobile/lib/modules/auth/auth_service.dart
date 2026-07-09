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

  /// `POST /auth/login` with `auth_method: "apple" | "google"`. The backend
  /// verifies [idToken] against the provider's JWKS and get-or-creates the
  /// account (login and signup are idempotent server-side).
  ///
  /// Throws [ApiException] on a rejected token (401 `oauth_invalid_token`),
  /// OAuth disabled in this environment (400 `oauth_unavailable`), or
  /// transport errors.
  Future<AuthResponse> loginWithOAuth({
    required String provider,
    required String idToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/login',
        data: {
          'auth_method': provider,
          _idTokenField(provider): idToken,
        },
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /auth/signup` with `auth_method: "apple" | "google"`. Consent is
  /// implied by the screen copy, same as email signup. Idempotent with
  /// [loginWithOAuth] server-side — a returning user is simply signed in.
  ///
  /// Throws [ApiException] on the same failures as [loginWithOAuth].
  Future<AuthResponse> signupWithOAuth({
    required String provider,
    required String idToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/signup',
        data: {
          'auth_method': provider,
          _idTokenField(provider): idToken,
          'agreed_to_terms': true,
          'agreed_to_privacy': true,
        },
      );
      return AuthResponse.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static String _idTokenField(String provider) =>
      provider == 'apple' ? 'apple_id_token' : 'google_id_token';

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

  /// `POST /auth/reset-password` — sets a new password using the opaque token
  /// from the reset email. On success (204) the backend revokes all of the
  /// user's refresh tokens, so they must sign in again.
  ///
  /// Throws [ApiException] on an invalid/expired/used token (400
  /// `invalid_reset_token`), a weak password (422), or transport errors.
  Future<void> resetPassword({
    required String token,
    required String newPassword,
  }) async {
    try {
      await _dio.post<void>(
        '/auth/reset-password',
        data: {'token': token, 'new_password': newPassword},
      );
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
