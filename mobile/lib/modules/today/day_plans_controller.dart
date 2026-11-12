import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/session_epoch.dart';
import 'day_plans_service.dart';
import 'models/day_plan.dart';

/// The next seven days' plans, keyed by local calendar day — loaded from
/// `GET /today/plans` and kept in step with every save.
///
/// The screens only talk to this controller. Writes throw [ApiException]
/// (the caller shows the message); a failed load just leaves what's there.
class DayPlansController extends StateNotifier<Map<DateTime, DayPlan>> {
  DayPlansController(this._service, {bool load = true}) : super(const {}) {
    if (load) unawaited(this.load());
  }

  final DayPlansService _service;

  /// Days a weekly repeat covers — including ones cleared "just this once",
  /// which have no plan in [state].
  Set<DateTime> _repeating = const {};

  DayPlan? planFor(DateTime date) => state[dayOnly(date)];

  /// A weekly repeat covers [date] (planned or cleared just for that day).
  bool repeats(DateTime date) => _repeating.contains(dayOnly(date));

  /// (Re)loads today + the next six days. Best-effort.
  Future<void> load() async {
    final days = nextSevenDays();
    try {
      final resolved = await _service.list(from: days.first, to: days.last);
      if (!mounted) return;
      _repeating = {
        for (final d in resolved)
          if (d.repeatsWeekly) d.date,
      };
      state = {
        for (final d in resolved)
          if (d.plan != null) d.date: d.plan!,
      };
    } catch (_) {
      // Keep the last good week; the next load retries.
    }
  }

  /// Saves [plan]: just its date, or as its weekday's repeat from that date
  /// on (which changes later days too, so the week is reloaded).
  Future<void> save(
    DayPlan plan, {
    DayPlanScope scope = DayPlanScope.day,
  }) async {
    final day = await _service.save(plan, scope: scope);
    if (scope == DayPlanScope.day) {
      _apply(day);
    } else {
      await load();
    }
  }

  /// Clears [date] just for that day, or stops its weekday repeating.
  Future<void> clear(
    DateTime date, {
    DayPlanScope scope = DayPlanScope.day,
  }) async {
    final day = await _service.clear(date, scope: scope);
    if (scope == DayPlanScope.day) {
      _apply(day);
    } else {
      await load();
    }
  }

  /// Turning "Repeat every …" off on a repeating day: stop the repeat from
  /// this date, then keep [plan] for this day only.
  Future<void> stopRepeatAndSave(DayPlan plan) async {
    await _service.clear(plan.date, scope: DayPlanScope.fromNow);
    await save(plan);
  }

  /// Whether [restore] can put [date] back exactly as [previous] — true
  /// unless it came from a repeat (an override can't be turned back into
  /// "follows the repeat").
  bool canRestore(DayPlan? previous) =>
      previous == null || !previous.fromRepeat;

  /// Undo for a one-day save or clear: puts [date] back to [previous].
  Future<void> restore(DateTime date, DayPlan? previous) async {
    if (previous == null) {
      await clear(date);
    } else {
      await save(previous);
    }
  }

  /// Quick start: plans every day in [days] that matches [when] and has
  /// nothing planned — never a day the user set or cleared themselves.
  /// Saves one at a time; returns how many it planned.
  Future<int> fill(
    List<DateTime> days, {
    required bool Function(DateTime day) when,
    required DayOccasion occasion,
  }) async {
    var filled = 0;
    for (final day in days.map(dayOnly)) {
      if (!when(day) || state.containsKey(day) || repeats(day)) continue;
      await save(DayPlan(date: day, occasion: occasion, dress: occasion.dress));
      filled++;
    }
    return filled;
  }

  void _apply(DayPlanDay day) {
    _repeating = day.repeatsWeekly
        ? {..._repeating, day.date}
        : ({..._repeating}..remove(day.date));
    final plan = day.plan;
    state = plan == null
        ? ({...state}..remove(day.date))
        : {...state, day.date: plan};
  }
}

final dayPlansProvider =
    StateNotifierProvider<DayPlansController, Map<DateTime, DayPlan>>((ref) {
      ref.watch(sessionEpochProvider); // user-scoped
      return DayPlansController(ref.read(dayPlansServiceProvider));
    });
