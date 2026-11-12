import 'package:dio/dio.dart';
import 'package:mobile/modules/today/day_plans_service.dart';
import 'package:mobile/modules/today/models/day_plan.dart';

/// In-memory `/today/plans` with the backend's rules: a date's own plan
/// (or skip) wins, else the weekday's repeat covering that date, else none.
/// `from_now` ends the old repeat the day before and drops its skips.
class FakeDayPlansService extends DayPlansService {
  FakeDayPlansService({List<DayPlan> plans = const []}) : super(Dio()) {
    for (final p in plans) {
      _own[dayOnly(p.date)] = p;
    }
  }

  /// A date's own row: a plan, or null = skipped.
  final _own = <DateTime, DayPlan?>{};
  final _rules = <_Rule>[];

  /// Every call, e.g. `save work_day 2026-11-13 day`.
  final calls = <String>[];

  /// Seeds a repeat directly (e.g. one that started weeks ago).
  void addRepeat(DayPlan plan, {required DateTime startsOn}) =>
      _rules.add(_Rule(plan, dayOnly(startsOn), null));

  @override
  Future<List<DayPlanDay>> list({
    required DateTime from,
    required DateTime to,
  }) async {
    calls.add('list ${apiDate(from)} ${apiDate(to)}');
    return [
      for (
        var d = dayOnly(from);
        !d.isAfter(dayOnly(to));
        d = DateTime(d.year, d.month, d.day + 1)
      )
        _resolve(d),
    ];
  }

  @override
  Future<DayPlanDay> save(DayPlan plan, {required DayPlanScope scope}) async {
    final day = dayOnly(plan.date);
    calls.add('save ${plan.occasion.wire} ${apiDate(day)} ${scope.wire}');
    if (scope == DayPlanScope.day) {
      _own[day] = plan;
    } else {
      _endRepeatFrom(day);
      _rules.add(_Rule(plan, day, null));
      _own.remove(day);
    }
    return _resolve(day);
  }

  @override
  Future<DayPlanDay> clear(DateTime date, {required DayPlanScope scope}) async {
    final day = dayOnly(date);
    calls.add('clear ${apiDate(day)} ${scope.wire}');
    if (scope == DayPlanScope.day) {
      if (_covering(day) != null) {
        _own[day] = null; // skip
      } else {
        _own.remove(day);
      }
    } else {
      _endRepeatFrom(day);
      _own.remove(day);
    }
    return _resolve(day);
  }

  _Rule? _covering(DateTime d) {
    for (final r in _rules) {
      if (r.plan.date.weekday == d.weekday &&
          !r.startsOn.isAfter(d) &&
          (r.endsOn == null || !r.endsOn!.isBefore(d))) {
        return r;
      }
    }
    return null;
  }

  void _endRepeatFrom(DateTime day) {
    _rules.removeWhere(
      (r) => r.plan.date.weekday == day.weekday && !r.startsOn.isBefore(day),
    );
    for (final r in _rules) {
      if (r.plan.date.weekday == day.weekday &&
          (r.endsOn == null || !r.endsOn!.isBefore(day))) {
        r.endsOn = DateTime(day.year, day.month, day.day - 1);
      }
    }
    _own.removeWhere(
      (d, p) => p == null && d.weekday == day.weekday && !d.isBefore(day),
    );
  }

  DayPlanDay _resolve(DateTime d) {
    final rule = _covering(d);
    final repeats = rule != null;
    DayPlan? plan;
    if (_own.containsKey(d)) {
      final own = _own[d];
      plan = own == null ? null : _at(own, d, repeats, fromRepeat: false);
    } else if (rule != null) {
      plan = _at(rule.plan, d, true, fromRepeat: true);
    }
    return DayPlanDay(date: d, plan: plan, repeatsWeekly: repeats);
  }

  static DayPlan _at(
    DayPlan p,
    DateTime d,
    bool repeats, {
    required bool fromRepeat,
  }) => DayPlan(
    date: d,
    occasion: p.occasion,
    dress: p.dress,
    note: p.note,
    repeatWeekly: repeats,
    fromRepeat: fromRepeat,
  );
}

class _Rule {
  _Rule(this.plan, this.startsOn, this.endsOn);
  final DayPlan plan;
  final DateTime startsOn;
  DateTime? endsOn;
}
