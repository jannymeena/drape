import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/analytics_provider.dart';
import '../../shared/providers/session_epoch.dart';
import '../../shared/services/analytics/analytics_events.dart';
import '../../shared/services/analytics/analytics_service.dart';
import 'models/measurements_draft.dart';
import 'models/onboarding_status.dart';
import 'models/starter_wardrobe.dart';
import 'models/style_blueprint_draft.dart';
import 'onboarding_service.dart';

/// Distinguishes "field not passed to copyWith" from "explicitly set to null"
/// (needed because `ageRange` can legitimately be null when the user skips it).
const Object _unset = Object();

/// The accumulating draft for the Style Blueprint onboarding flow.
///
/// Onboarding is seven screens that each contribute one piece of the profile;
/// this state is the single place those pieces live as the user advances, so
/// later steps (and the reveal) can read what earlier ones captured. Steps 2–7
/// accumulate in [blueprint]; step 1 and step 7 also fill the dedicated
/// [shoppingStyle] / [ageRange] / [styleGoals] fields, which have their own
/// backend columns.
///
/// [measurements] is filled by the eight measurement screens, which are no
/// longer part of onboarding — they're entered from the Shop/Profile tabs and
/// submitted in a single `POST /profile/measurements`.
/// [nextStep] holds the most recent backend `next_step` literal.
class OnboardingState {
  const OnboardingState({
    this.shoppingStyle,
    this.ageRange,
    this.styleGoals = const [],
    this.blueprint = const StyleBlueprintDraft(),
    this.measurements = const MeasurementsDraft(),
    this.nextStep,
  });

  /// Backend `ShoppingStyle` literal (e.g. `womens`), or null until chosen.
  final String? shoppingStyle;

  /// Backend `AgeRange` literal, or null (also the value when the user skips).
  final String? ageRange;

  /// Backend `StyleGoal` literals, empty until chosen.
  final List<String> styleGoals;

  /// Style-blueprint answers from steps 2–7.
  final StyleBlueprintDraft blueprint;

  /// Body measurements collected across the measurement screens.
  final MeasurementsDraft measurements;

  /// Most recent `next_step` returned by a profile mutation.
  final String? nextStep;

  OnboardingState copyWith({
    Object? shoppingStyle = _unset,
    Object? ageRange = _unset,
    List<String>? styleGoals,
    StyleBlueprintDraft? blueprint,
    MeasurementsDraft? measurements,
    Object? nextStep = _unset,
  }) {
    return OnboardingState(
      shoppingStyle: shoppingStyle == _unset
          ? this.shoppingStyle
          : shoppingStyle as String?,
      ageRange: ageRange == _unset ? this.ageRange : ageRange as String?,
      styleGoals: styleGoals ?? this.styleGoals,
      blueprint: blueprint ?? this.blueprint,
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

  /// Step 1 — persists shopping style + age range ([range] null = the user
  /// skipped that question). Returns the backend `next_step`. Throws
  /// [ApiException] (the screen shows it).
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) async {
    final next = await _service.setBlueprintIdentity(
      shoppingStyle: shoppingStyle,
      ageRange: ageRange,
    );
    state = state.copyWith(
      shoppingStyle: shoppingStyle,
      ageRange: ageRange,
      nextStep: next,
    );
    _analytics.capture(AnalyticsEvents.shoppingStyleSelected, {
      'style': shoppingStyle,
    });
    _analytics.capture(AnalyticsEvents.ageRangeSelected, {
      'range': ageRange ?? 'skipped',
    });
    return next;
  }

  /// Step 2 — body shape and fit preferences.
  Future<String> setBlueprintFit({
    required String bodyShape,
    required String fitTops,
    required String fitBottoms,
  }) async {
    final next = await _service.setBlueprintFit(
      bodyShape: bodyShape,
      fitTops: fitTops,
      fitBottoms: fitBottoms,
    );
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        bodyShape: bodyShape,
        fitTops: fitTops,
        fitBottoms: fitBottoms,
      ),
      nextStep: next,
    );
    return next;
  }

  /// Step 3 — the style card grid. [aesthetics] must be non-empty.
  Future<String> setBlueprintAesthetics(List<String> aesthetics) async {
    final next = await _service.setBlueprintAesthetics(aesthetics);
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(styleAesthetics: aesthetics),
      nextStep: next,
    );
    _analytics.capture(AnalyticsEvents.styleAestheticsSelected, {
      'count': aesthetics.length,
    });
    return next;
  }

  /// Step 4 — undertone and colour palettes. [palettes] must be non-empty.
  Future<String> setBlueprintColor({
    required String undertone,
    required List<String> palettes,
  }) async {
    final next = await _service.setBlueprintColor(
      undertone: undertone,
      palettes: palettes,
    );
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        undertone: undertone,
        colorPalettes: palettes,
      ),
      nextStep: next,
    );
    return next;
  }

  /// Step 5 — work context. [occupation] and [dressCode] may both be null.
  Future<String> setBlueprintLifestyle({
    required String? occupation,
    required String? dressCode,
    required String impressionGoal,
  }) async {
    final next = await _service.setBlueprintLifestyle(
      occupation: occupation,
      dressCode: dressCode,
      impressionGoal: impressionGoal,
    );
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        occupation: occupation,
        dressCode: dressCode,
        impressionGoal: impressionGoal,
      ),
      nextStep: next,
    );
    return next;
  }

  /// Step 6 — shopping attitude, accessories, brand tier.
  Future<String> setBlueprintHabits({
    required String shoppingFeeling,
    required String accessories,
    required String brandTier,
  }) async {
    final next = await _service.setBlueprintHabits(
      shoppingFeeling: shoppingFeeling,
      accessories: accessories,
      brandTier: brandTier,
    );
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        shoppingFeeling: shoppingFeeling,
        accessories: accessories,
        brandTier: brandTier,
      ),
      nextStep: next,
    );
    return next;
  }

  /// Step 7 — the three-month aspiration plus the (non-empty) style goals.
  Future<String> setBlueprintGoals({
    required String threeMonthFeeling,
    required List<String> goals,
  }) async {
    final next = await _service.setBlueprintGoals(
      threeMonthFeeling: threeMonthFeeling,
      goals: goals,
    );
    state = state.copyWith(
      styleGoals: goals,
      blueprint: state.blueprint.copyWith(threeMonthFeeling: threeMonthFeeling),
      nextStep: next,
    );
    _analytics.capture(AnalyticsEvents.styleGoalsSelected, {
      'goals_count': goals.length,
    });
    return next;
  }

  /// The reveal's "Build My Wardrobe" — closes out the blueprint.
  Future<String> completeBlueprint() async {
    final next = await _service.completeBlueprint();
    state = state.copyWith(nextStep: next);
    _analytics.capture(AnalyticsEvents.styleBlueprintCompleted);
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
  /// Measurements sit outside onboarding, so this doesn't move [nextStep].
  /// Throws [ApiException].
  Future<void> submitMeasurements() async {
    if (!state.measurements.hasAllRequired) {
      throw const ApiException(
        code: 'incomplete_measurements',
        message: 'Please enter all required measurements before continuing.',
      );
    }
    await _service.submitMeasurements(state.measurements);
    _analytics.capture(AnalyticsEvents.allMeasurementsCompleted);
  }

  /// Assigns a starter wardrobe (a capsule of AWIN products picked for the
  /// user's shopping style) and materializes its items into the wardrobe. Returns the result so the screen
  /// can confirm how many pieces were added. Throws [ApiException].
  Future<StarterWardrobeResult> assignStarterWardrobe() {
    return _service.assignStarterWardrobe();
  }

  /// Fetches the resume target on launch *and* seeds the draft from the backend
  /// so resumed onboarding screens are prefilled with what the user already
  /// saved (the blueprint answers and any measurements) instead of
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
      blueprint: status.styleProfile,
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
