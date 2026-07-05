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

  /// `GET /support/feature-requests` — public board (score + caller's vote).
  Future<List<FeatureRequestItem>> getFeatureBoard() async {
    try {
      final r =
          await _dio.get<Map<String, dynamic>>('/support/feature-requests');
      return (r.data!['items'] as List<dynamic>)
          .map((e) => FeatureRequestItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /support/feature-requests/{id}/vote` — +1/-1 upsert, 0 clears.
  Future<void> voteFeature(String ticketId, int vote) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/support/feature-requests/$ticketId/vote',
        data: {'vote': vote},
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

/// One row on the public feature-request board.
class FeatureRequestItem {
  const FeatureRequestItem({
    required this.id,
    required this.title,
    required this.message,
    required this.status,
    required this.score,
    required this.myVote,
  });

  final String id;
  final String title;
  final String message;
  final String status;
  final int score;
  final int myVote; // -1 | 0 | 1

  factory FeatureRequestItem.fromJson(Map<String, dynamic> json) {
    final message = json['message'] as String? ?? '';
    return FeatureRequestItem(
      id: json['id'] as String,
      title: (json['subject'] as String?)?.isNotEmpty == true
          ? json['subject'] as String
          : (message.length > 60 ? '${message.substring(0, 60)}…' : message),
      message: message,
      status: json['status'] as String? ?? 'open',
      score: json['score'] as int? ?? 0,
      myVote: json['my_vote'] as int? ?? 0,
    );
  }
}

final featureBoardProvider =
    FutureProvider.autoDispose<List<FeatureRequestItem>>((ref) {
  return ref.read(settingsServiceProvider).getFeatureBoard();
});
