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
///
/// The seven `setBlueprint*` methods are the Style Blueprint steps, in flow
/// order. Measurements are no longer part of that chain — [submitMeasurements]
/// is called from the Shop/Profile tabs and doesn't advance onboarding.
class OnboardingService {
  OnboardingService(this._dio);

  final Dio _dio;

  /// Step 1 — `POST /profile/style-blueprint/identity`. [ageRange] is null when
  /// the user skips that (optional) question; the backend records the skip.
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) async {
    return _postStep('/profile/style-blueprint/identity', {
      'shopping_style': shoppingStyle,
      'age_range': ageRange,
    });
  }

  /// Step 2 — `POST /profile/style-blueprint/fit`.
  Future<String> setBlueprintFit({
    required String bodyShape,
    required String fitTops,
    required String fitBottoms,
  }) async {
    return _postStep('/profile/style-blueprint/fit', {
      'body_shape': bodyShape,
      'fit_tops': fitTops,
      'fit_bottoms': fitBottoms,
    });
  }

  /// Step 3 — `POST /profile/style-blueprint/aesthetics`. [aesthetics] must be
  /// non-empty (the backend rejects an empty list with 422).
  Future<String> setBlueprintAesthetics(List<String> aesthetics) async {
    return _postStep('/profile/style-blueprint/aesthetics', {
      'style_aesthetics': aesthetics,
    });
  }

  /// Step 4 — `POST /profile/style-blueprint/color`. [palettes] must be
  /// non-empty.
  Future<String> setBlueprintColor({
    required String undertone,
    required List<String> palettes,
  }) async {
    return _postStep('/profile/style-blueprint/color', {
      'undertone': undertone,
      'color_palettes': palettes,
    });
  }

  /// Step 5 — `POST /profile/style-blueprint/lifestyle`. [occupation] and
  /// [dressCode] are both null-able: the dress-code question is skipped for
  /// users who aren't currently working.
  Future<String> setBlueprintLifestyle({
    required String? occupation,
    required String? dressCode,
    required String impressionGoal,
  }) async {
    return _postStep('/profile/style-blueprint/lifestyle', {
      'occupation': occupation,
      'dress_code': dressCode,
      'impression_goal': impressionGoal,
    });
  }

  /// Step 6 — `POST /profile/style-blueprint/habits`.
  Future<String> setBlueprintHabits({
    required String shoppingFeeling,
    required String accessories,
    required String brandTier,
  }) async {
    return _postStep('/profile/style-blueprint/habits', {
      'shopping_feeling': shoppingFeeling,
      'accessories': accessories,
      'brand_tier': brandTier,
    });
  }

  /// Step 7 — `POST /profile/style-blueprint/goals`. [goals] must be non-empty.
  Future<String> setBlueprintGoals({
    required String threeMonthFeeling,
    required List<String> goals,
  }) async {
    return _postStep('/profile/style-blueprint/goals', {
      'three_month_feeling': threeMonthFeeling,
      'style_goals': goals,
    });
  }

  /// `POST /profile/style-blueprint/complete` — the reveal screen's
  /// "Build My Wardrobe", which closes out the blueprint.
  Future<String> completeBlueprint() async {
    return _postStep('/profile/style-blueprint/complete', const {});
  }

  /// `POST /profile/save-progress` — records where the user paused so the next
  /// session resumes there. [lastCompletedStep] is an `OnboardingStep` literal.
  Future<String> saveProgress(String lastCompletedStep) async {
    return _postStep('/profile/save-progress', {
      'last_completed_step': lastCompletedStep,
    });
  }

  /// `POST /profile/measurements` — bulk submit of all measurements at once;
  /// the backend encrypts them and marks measurements complete. Measurements
  /// sit outside onboarding, so this deliberately returns nothing and does not
  /// move the step pointer. A missing required field or an out-of-range value
  /// surfaces as a 422 [ApiException].
  Future<void> submitMeasurements(MeasurementsDraft draft) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/profile/measurements',
        data: draft.toJson(),
      );
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
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

  /// `GET /profile/measurements` — the user's saved measurements, or null when
  /// they haven't submitted any yet (the backend returns 404). Used to prefill
  /// the measurement screens when onboarding is resumed.
  Future<MeasurementsDraft?> getMeasurements() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/profile/measurements',
      );
      return MeasurementsDraft.fromJson(response.data!);
    } on DioException catch (e) {
      final err = ApiException.fromDio(e);
      if (err.statusCode == 404) return null;
      throw err;
    }
  }

  /// `POST /starter-wardrobe/assign` — the server picks a capsule of AWIN
  /// products for the user's shopping_style and materializes it into the
  /// wardrobe. 503 while the catalog is still being tagged (fresh sync).
  Future<StarterWardrobeResult> assignStarterWardrobe() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/starter-wardrobe/assign',
      );
      return StarterWardrobeResult.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// `POST /starter-wardrobe/deactivate` — manual opt-out of the starter kit.
  /// (Auto-deactivation at 10 real items is handled server-side.)
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

/// Live onboarding/measurement status for the Today resume banner. Invalidate
/// after saving measurements so the banner's progress updates right away.
final onboardingStatusProvider =
    FutureProvider.autoDispose<OnboardingStatus>((ref) {
  return ref.read(onboardingServiceProvider).getOnboardingStatus();
});
