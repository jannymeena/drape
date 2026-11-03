import 'dart:async';

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

  // ─── Background saves ──────────────────────────────────────────────────
  //
  // Each step updates the draft at once and the screen moves straight on; the
  // step's save runs in the background. Saves go out one at a time, in step
  // order, so the backend's resume pointer only ever moves the way the user
  // did. A save that fails is kept and retried ahead of the next one; the
  // reveal's [completeBlueprint] waits for every save, and is where a save
  // that keeps failing finally surfaces.

  /// The tail of the save queue. Never errors, so the next save always runs.
  Future<void> _queue = Future.value();

  /// Failed saves awaiting a retry, keyed by step, oldest first. Re-answering
  /// a step replaces its entry.
  final _failed = <String, Future<String> Function()>{};

  /// Queues [send] as [step]'s save. The returned future completes with the
  /// backend `next_step`, or throws [ApiException] if this save — or an
  /// earlier failed one it retried first — couldn't be made. Callers that
  /// move on without waiting can ignore it: failures are kept for a retry.
  Future<String> _save(String step, Future<String> Function() send) {
    _failed.remove(step);
    final done = _queue.then((_) async {
      try {
        await _retryFailed();
        final next = await send();
        state = state.copyWith(nextStep: next);
        return next;
      } on ApiException {
        _failed[step] = send;
        rethrow;
      }
    });
    _queue = done.then((_) {}, onError: (Object _) {});
    return done;
  }

  Future<void> _retryFailed() async {
    for (final MapEntry(key: step, value: send) in [..._failed.entries]) {
      final next = await send(); // stops at the first that still fails
      _failed.remove(step);
      state = state.copyWith(nextStep: next);
    }
  }

  /// Waits until every answer so far is saved, retrying any that failed.
  /// Throws [ApiException] if one still can't be saved.
  Future<void> _allSaved() => _queue.then((_) => _retryFailed());

  // ─── Steps ─────────────────────────────────────────────────────────────

  /// Step 1 — shopping style + age range ([ageRange] null = the user skipped
  /// that question). The draft updates at once, so step 2 can render the
  /// right shape set before the save lands. See [_save] for the future.
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) {
    state = state.copyWith(shoppingStyle: shoppingStyle, ageRange: ageRange);
    _analytics.capture(AnalyticsEvents.shoppingStyleSelected, {
      'style': shoppingStyle,
    });
    _analytics.capture(AnalyticsEvents.ageRangeSelected, {
      'range': ageRange ?? 'skipped',
    });
    return _save(
      'identity',
      () => _service.setBlueprintIdentity(
        shoppingStyle: shoppingStyle,
        ageRange: ageRange,
      ),
    );
  }

  /// Step 2 — body shape and fit preferences. A null [bodyShape] is "Not
  /// sure", and clears any shape picked earlier.
  Future<String> setBlueprintFit({
    required String? bodyShape,
    required String fitTops,
    required String fitBottoms,
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        bodyShape: bodyShape,
        clearBodyShape: bodyShape == null,
        fitTops: fitTops,
        fitBottoms: fitBottoms,
      ),
    );
    return _save(
      'fit',
      () => _service.setBlueprintFit(
        bodyShape: bodyShape,
        fitTops: fitTops,
        fitBottoms: fitBottoms,
      ),
    );
  }

  /// Step 3 — the style card grid ([aesthetics], non-empty) and the optional
  /// micro-aesthetic tags ([micro]).
  Future<String> setBlueprintAesthetics(
    List<String> aesthetics, {
    List<String> micro = const [],
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        styleAesthetics: aesthetics,
        microAesthetics: micro,
      ),
    );
    _analytics.capture(AnalyticsEvents.styleAestheticsSelected, {
      'count': aesthetics.length,
      'micro_count': micro.length,
    });
    return _save(
      'aesthetics',
      () => _service.setBlueprintAesthetics(aesthetics, micro: micro),
    );
  }

  /// Step 4 — skin shade (1–10) and undertone; both null when the user
  /// skips the step.
  Future<String> setBlueprintColor({
    required int? skinShade,
    required String? undertone,
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        skinShade: skinShade,
        undertone: undertone,
        clearSkinTone: skinShade == null && undertone == null,
      ),
    );
    return _save(
      'color',
      () => _service.setBlueprintColor(
        skinShade: skinShade,
        undertone: undertone,
      ),
    );
  }

  /// Step 5 — the colour palettes the user gravitates to ([palettes],
  /// non-empty) and the colours they'd rather avoid. See [_save] for the
  /// future.
  Future<String> setBlueprintPalettes(
    List<String> palettes, {
    List<String> avoid = const [],
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        colorPalettes: palettes,
        avoidColors: avoid,
      ),
    );
    return _save(
      'palettes',
      () => _service.setBlueprintPalettes(palettes: palettes, avoid: avoid),
    );
  }

  /// The earlier step 5 — work context. Its screen was replaced by the
  /// palettes step; kept for when the API is reconnected. [occupation] and [dressCode] may both be null.
  Future<String> setBlueprintLifestyle({
    required String? occupation,
    required String? dressCode,
    required String impressionGoal,
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        occupation: occupation,
        dressCode: dressCode,
        impressionGoal: impressionGoal,
      ),
    );
    return _save(
      'lifestyle',
      () => _service.setBlueprintLifestyle(
        occupation: occupation,
        dressCode: dressCode,
        impressionGoal: impressionGoal,
      ),
    );
  }

  /// Step 6 — shopping attitude, accessories, brand tier.
  Future<String> setBlueprintHabits({
    required String shoppingFeeling,
    required String accessories,
    required String brandTier,
  }) {
    state = state.copyWith(
      blueprint: state.blueprint.copyWith(
        shoppingFeeling: shoppingFeeling,
        accessories: accessories,
        brandTier: brandTier,
      ),
    );
    return _save(
      'habits',
      () => _service.setBlueprintHabits(
        shoppingFeeling: shoppingFeeling,
        accessories: accessories,
        brandTier: brandTier,
      ),
    );
  }

  /// Step 7 — the three-month aspiration plus the (non-empty) style goals.
  Future<String> setBlueprintGoals({
    required String threeMonthFeeling,
    required List<String> goals,
  }) {
    state = state.copyWith(
      styleGoals: goals,
      blueprint: state.blueprint.copyWith(threeMonthFeeling: threeMonthFeeling),
    );
    _analytics.capture(AnalyticsEvents.styleGoalsSelected, {
      'goals_count': goals.length,
    });
    return _save(
      'goals',
      () => _service.setBlueprintGoals(
        threeMonthFeeling: threeMonthFeeling,
        goals: goals,
      ),
    );
  }

  /// The reveal's "Build My Wardrobe" — closes out the blueprint, once every
  /// step's answers are saved. Throws [ApiException] if one still can't be
  /// saved, or the completion itself fails.
  Future<String> completeBlueprint() async {
    // Measurements are optional: one more try for any unsent ones, without
    // holding the blueprint up for them.
    unawaited(_sendMeasurements());
    await _allSaved();
    final next = await _service.completeBlueprint();
    state = state.copyWith(nextStep: next);
    _analytics.capture(AnalyticsEvents.styleBlueprintCompleted);
    return next;
  }

  /// Records where the user paused (an `OnboardingStep` literal) so the next
  /// session can resume there. Throws [ApiException].
  Future<String> saveProgress(String step) async {
    await _allSaved(); // keep the resume pointer behind any queued saves
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

  /// Measurements given to [saveMeasurements] and not yet saved, metric.
  final _unsentMeasurements = <MeasurementField, double>{};
  var _unsentUnits = 'metric';

  /// The tail of the measurement saves, which go out one at a time. Never
  /// errors.
  Future<void> _measurementSaves = Future.value();

  /// Stores [cm] (metric) in the draft, and saves just those measurements to
  /// the profile in the background (`PATCH /profile/measurements`): nothing
  /// waits for it, and a failure never interrupts the user. Measurements are
  /// optional, so they stay out of the step-save queue — a failed one must
  /// not hold up the blueprint. One that fails for want of a connection or
  /// a server error is kept and sent with the next, and again when the
  /// blueprint is completed; one the server rejects is dropped.
  void saveMeasurements(
    Map<MeasurementField, double> cm, {
    required bool imperial,
  }) {
    for (final MapEntry(key: field, value: value) in cm.entries) {
      setMeasurement(field, value, imperial: imperial);
    }
    _unsentMeasurements.addAll(cm);
    _unsentUnits = imperial ? 'imperial' : 'metric';
    unawaited(_sendMeasurements());
  }

  Future<void> _sendMeasurements() {
    return _measurementSaves = _measurementSaves.then((_) async {
      if (_unsentMeasurements.isEmpty) return;
      final batch = Map.of(_unsentMeasurements);
      // Forget what was sent, unless it was changed meanwhile.
      void sent() => batch.forEach((field, value) {
        if (_unsentMeasurements[field] == value) {
          _unsentMeasurements.remove(field);
        }
      });
      try {
        await _service.saveSomeMeasurements(batch, unitSystem: _unsentUnits);
        sent();
      } on ApiException catch (e) {
        final status = e.statusCode;
        // Rejected (bad values, signed out): retrying won't change that.
        if (status != null && status >= 400 && status < 500) sent();
      } catch (_) {
        // Kept for the next try.
      }
    });
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
