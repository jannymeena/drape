import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/session_epoch.dart';
import 'models/day_plan.dart';

/// The user's day plans, keyed by local calendar day.
///
/// UI-only for now: held in memory for the session (reset on logout via the
/// session epoch). When the day-plans API lands (BACKEND_CHANGES 1.0) this is
/// where load/save calls go — the screens only talk to this controller.
class DayPlansController extends StateNotifier<Map<DateTime, DayPlan>> {
  DayPlansController() : super(const {});

  DayPlan? planFor(DateTime date) => state[dayOnly(date)];

  void save(DayPlan plan) {
    state = {...state, dayOnly(plan.date): plan.copyWith(date: dayOnly(plan.date))};
  }

  void clear(DateTime date) {
    state = {...state}..remove(dayOnly(date));
  }

  /// Puts back whatever [date] had before an edit (Undo on the toast).
  void restore(DateTime date, DayPlan? previous) {
    if (previous == null) {
      clear(date);
    } else {
      save(previous);
    }
  }

  /// Quick start: fills every day in [days] that matches [when] and has no
  /// plan yet — never overwrites a day the user set themselves. Returns how
  /// many days it filled.
  int fill(
    List<DateTime> days, {
    required bool Function(DateTime day) when,
    required DayOccasion occasion,
  }) {
    final next = {...state};
    var filled = 0;
    for (final day in days.map(dayOnly)) {
      if (!when(day) || next.containsKey(day)) continue;
      next[day] = DayPlan(date: day, occasion: occasion, dress: occasion.dress);
      filled++;
    }
    state = next;
    return filled;
  }
}

final dayPlansProvider =
    StateNotifierProvider<DayPlansController, Map<DateTime, DayPlan>>((ref) {
  ref.watch(sessionEpochProvider); // user-scoped
  return DayPlansController();
});
