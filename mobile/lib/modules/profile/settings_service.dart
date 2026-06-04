import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/app_settings.dart';

/// Backend `/settings`, `/support/*`, and `/account/*` endpoints that back the
/// Settings, Support, and Data/Privacy areas of the Profile tab. Every
/// [DioException] becomes a typed [ApiException]; the bearer is attached by the
/// auth interceptor.
class SettingsService {
  SettingsService(this._dio);

  final Dio _dio;

  /// `GET /settings`.
  Future<AppSettings> getSettings() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/settings');
      return AppSettings.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `PATCH /settings` — only the supplied keys are written. Returns the full
  /// updated settings.
  Future<AppSettings> updateSettings(Map<String, dynamic> changes) async {
    try {
      final r = await _dio.patch<Map<String, dynamic>>('/settings', data: changes);
      return AppSettings.fromJson(r.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /support/{contact|feature-request|bug-report}`. [kind] is one of
  /// `contact`, `feature-request`, `bug-report`.
  Future<void> submitSupport({
    required String kind,
    String? subject,
    required String message,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/support/$kind',
        data: {
          'subject': ?subject,
          'message': message,
          'extra': ?extra,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /account/export` — the portable JSON snapshot of the user's data.
  Future<Map<String, dynamic>> exportData() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/account/export');
      return r.data!;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `DELETE /account` — permanently deletes the caller's account.
  Future<void> deleteAccount() async {
    try {
      await _dio.delete<void>('/account');
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final settingsServiceProvider = Provider<SettingsService>((ref) {
  return SettingsService(ref.read(dioProvider));
});

/// Loads the user's settings. `autoDispose` so each settings screen refetches
/// fresh on open — screens hold their own local edit state and PATCH through
/// [SettingsService], so there's no shared cache to keep in sync.
final settingsProvider = FutureProvider.autoDispose<AppSettings>((ref) {
  return ref.read(settingsServiceProvider).getSettings();
});
