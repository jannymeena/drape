import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/analytics_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../../shared/services/analytics/analytics_events.dart';
import '../../shared/services/analytics/analytics_service.dart';
import 'models/measurements_draft.dart';
import 'models/onboarding_status.dart';
import 'models/starter_wardrobe.dart';
import 'onboarding_service.dart';

/// Distinguishes "field not passed to copyWith" from "explicitly set to null"
/// (needed because `ageRange` can legitimately be null when the user skips it).
const Object _unset = Object();

/// The accumulating draft for the multi-screen onboarding flow.
///
/// Onboarding spans ~10 screens that each contribute one piece of the profile;
/// this state is the single place those pieces live as the user advances, so
/// later steps can read what earlier ones captured. Most notably, the eight
/// measurement screens write into [measurements] one value at a time, then the
/// last screen submits them in a single `POST /profile/measurements`.
/// [nextStep] holds the most recent backend `next_step` literal.
class OnboardingState {
  const OnboardingState({
    this.shoppingStyle,
    this.ageRange,
    this.styleGoals = const [],
    this.measurements = const MeasurementsDraft(),
    this.nextStep,
  });

  /// Backend `ShoppingStyle` literal (e.g. `womens`), or null until chosen.
  final String? shoppingStyle;

  /// Backend `AgeRange` literal, or null (also the value when the user skips).
  final String? ageRange;

  /// Backend `StyleGoal` literals, empty until chosen.
  final List<String> styleGoals;

  /// Body measurements collected across the measurement screens.
  final MeasurementsDraft measurements;

  /// Most recent `next_step` returned by a profile mutation.
  final String? nextStep;

  OnboardingState copyWith({
    Object? shoppingStyle = _unset,
    Object? ageRange = _unset,
    List<String>? styleGoals,
    MeasurementsDraft? measurements,
    Object? nextStep = _unset,
  }) {
    return OnboardingState(
      shoppingStyle: shoppingStyle == _unset
          ? this.shoppingStyle
          : shoppingStyle as String?,
      ageRange: ageRange == _unset ? this.ageRange : ageRange as String?,
      styleGoals: styleGoals ?? this.styleGoals,
      measurements: measurements ?? this.measurements,
      nextStep: nextStep == _unset ? this.nextStep : nextStep as String?,
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingState> {
  OnboardingController(this._service, this._analytics)
      : super(const OnboardingState());

  final OnboardingService _service;
  final AnalyticsService _analytics;

  /// Persists the shopping style and stores it in the draft. Returns the
  /// backend `next_step`. Throws [ApiException] on failure (the screen shows it).
  Future<String> setShoppingStyle(String style) async {
    final next = await _service.setShoppingStyle(style);
    state = state.copyWith(shoppingStyle: style, nextStep: next);
    _analytics
        .capture(AnalyticsEvents.shoppingStyleSelected, {'style': style});
    return next;
  }

  /// Persists the age range ([range] null = the user skipped this step) and
  /// stores it. Returns the backend `next_step`. Throws [ApiException].
  Future<String> setAgeRange(String? range) async {
    final next = await _service.setAgeRange(range);
    state = state.copyWith(ageRange: range, nextStep: next);
    _analytics.capture(
      AnalyticsEvents.ageRangeSelected,
      {'range': range ?? 'skipped'},
    );
    return next;
  }

  /// Persists the (non-empty) style goals and stores them. Returns the backend
  /// `next_step`. Throws [ApiException].
  Future<String> setStyleGoals(List<String> goals) async {
    final next = await _service.setStyleGoals(goals);
    state = state.copyWith(styleGoals: goals, nextStep: next);
    _analytics.capture(
      AnalyticsEvents.styleGoalsSelected,
      {'goals_count': goals.length},
    );
    return next;
  }

  /// Records where the user paused (an `OnboardingStep` literal) so the next
  /// session can resume there. Throws [ApiException].
  Future<String> saveProgress(String step) async {
    final next = await _service.saveProgress(step);
    state = state.copyWith(nextStep: next);
    return next;
  }

  /// Stores one measurement (already converted to metric) in the draft. No
  /// network call — measurements are submitted in bulk by [submitMeasurements].
  void setMeasurement(
    MeasurementField field,
    double? metric, {
    required bool imperial,
  }) {
    state = state.copyWith(
      measurements: state.measurements.setField(
        field,
        metric,
        unitSystem: imperial ? 'imperial' : 'metric',
      ),
    );
  }

  /// Submits all collected measurements in one call. Guards client-side that the
  /// required set is complete (the per-screen Continue gating should already
  /// guarantee this) so we surface a friendly message instead of a raw 422.
  /// Returns the backend `next_step` (`avatar_reveal`). Throws [ApiException].
  Future<String> submitMeasurements() async {
    if (!state.measurements.hasAllRequired) {
      throw const ApiException(
        code: 'incomplete_measurements',
        message: 'Please enter all required measurements before continuing.',
      );
    }
    final next = await _service.submitMeasurements(state.measurements);
    state = state.copyWith(nextStep: next);
    _analytics.capture(AnalyticsEvents.allMeasurementsCompleted);
    return next;
  }

  /// Assigns a starter wardrobe (auto-picked when [templateId] is null) and
  /// materializes its items into the wardrobe. Returns the result so the screen
  /// can confirm how many pieces were added. Throws [ApiException].
  Future<StarterWardrobeResult> assignStarterWardrobe({String? templateId}) {
    return _service.assignStarterWardrobe(templateId: templateId);
  }

  /// Fetches the resume target on launch *and* seeds the draft from the backend
  /// so resumed onboarding screens are prefilled with what the user already
  /// saved (shopping style, age range, style goals, and measurements) instead of
  /// starting blank. The measurements fetch is best-effort — a 404 (none yet) or
  /// transient failure leaves them empty rather than blocking the resume.
  /// Returns the status so the caller can route. Throws [ApiException] only if
  /// the status fetch itself fails.
  Future<OnboardingStatus> loadAndHydrate() async {
    final status = await _service.getOnboardingStatus();
    MeasurementsDraft? measurements;
    try {
      measurements = await _service.getMeasurements();
    } on ApiException {
      measurements = null;
    }
    state = state.copyWith(
      shoppingStyle: status.shoppingStyle,
      ageRange: status.ageRange,
      styleGoals: status.styleGoals ?? const <String>[],
      measurements: measurements ?? const MeasurementsDraft(),
      nextStep: status.nextStep,
    );
    return status;
  }
}

final onboardingControllerProvider =
    StateNotifierProvider<OnboardingController, OnboardingState>((ref) {
  // User-scoped draft: rebuilt on login/logout so a register → logout →
  // register cycle never prefills the next account with this one's answers.
  ref.watch(sessionEpochProvider);
  return OnboardingController(
    ref.read(onboardingServiceProvider),
    ref.read(analyticsProvider),
  );
});
