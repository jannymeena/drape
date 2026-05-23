import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/measurements_draft.dart';
import 'models/onboarding_status.dart';
import 'models/starter_wardrobe.dart';

/// Talks to the backend `/profile/*` onboarding endpoints. Like [AuthService],
/// every [DioException] is translated to a typed [ApiException] so the UI never
/// sees a raw Dio failure. The bearer token is attached by the auth interceptor.
///
/// Each profile-setup mutation returns the backend's `next_step` literal (from
/// `ProfileStepResponse`); the caller persists it for resume-on-launch.
/// Measurements + starter-wardrobe methods are added in later sub-phases.
class OnboardingService {
  OnboardingService(this._dio);

  final Dio _dio;

  /// `POST /profile/shopping-style`. Returns the backend's `next_step`.
  Future<String> setShoppingStyle(String shoppingStyle) async {
    return _postStep('/profile/shopping-style', {'shopping_style': shoppingStyle});
  }

  /// `POST /profile/age-range`. [ageRange] is null when the user skips this
  /// (optional) step — the backend accepts null to record the skip explicitly.
  Future<String> setAgeRange(String? ageRange) async {
    return _postStep('/profile/age-range', {'age_range': ageRange});
  }

  /// `POST /profile/style-goals`. [goals] must be non-empty (backend rejects
  /// an empty list with 422).
  Future<String> setStyleGoals(List<String> goals) async {
    return _postStep('/profile/style-goals', {'style_goals': goals});
  }

  /// `POST /profile/save-progress` — records where the user paused so the next
  /// session resumes there. [lastCompletedStep] is an `OnboardingStep` literal.
  Future<String> saveProgress(String lastCompletedStep) async {
    return _postStep('/profile/save-progress', {
      'last_completed_step': lastCompletedStep,
    });
  }

  /// `POST /profile/measurements` — bulk submit of all measurements at once
  /// (the backend encrypts them, marks measurements complete, and advances
  /// onboarding to `avatar_reveal`, which it returns as `next_step`). A missing
  /// required field or an out-of-range value surfaces as a 422 [ApiException].
  Future<String> submitMeasurements(MeasurementsDraft draft) async {
    return _postStep('/profile/measurements', draft.toJson());
  }

  /// `GET /profile/onboarding-status` — completion flag + resume target.
  Future<OnboardingStatus> getOnboardingStatus() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/profile/onboarding-status',
      );
      return OnboardingStatus.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `GET /starter-wardrobe/templates` — the browsable starter-kit catalogue.
  Future<List<StarterTemplate>> getStarterTemplates() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/starter-wardrobe/templates',
      );
      final list = (response.data!['templates'] as List).cast<Map<String, dynamic>>();
      return list.map(StarterTemplate.fromJson).toList();
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /starter-wardrobe/assign` — assign a starter kit and materialize its
  /// items into the wardrobe. [templateId] null lets the server auto-pick from
  /// the user's shopping_style + age_range (neutral default if unmatched).
  Future<StarterWardrobeResult> assignStarterWardrobe({String? templateId}) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/starter-wardrobe/assign',
        data: {'template_id': templateId},
      );
      return StarterWardrobeResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /starter-wardrobe/deactivate` — manual opt-out of the starter kit.
  /// (Auto-deactivation at 15 real items is handled server-side.)
  Future<void> deactivateStarterWardrobe({String? reason}) async {
    try {
      await _dio.post<void>(
        '/starter-wardrobe/deactivate',
        data: {'reason': reason},
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Shared POST → `{success, next_step}` shape used by every profile mutation.
  Future<String> _postStep(String path, Map<String, dynamic> data) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: data);
      return response.data!['next_step'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref.read(dioProvider));
});
