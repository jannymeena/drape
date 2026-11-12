import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import '../../shared/providers/network_provider.dart';
import 'models/day_plan.dart';

/// One day as the API resolves it: its plan (null = nothing planned) and
/// whether a weekly repeat covers it.
class DayPlanDay {
  const DayPlanDay({
    required this.date,
    required this.plan,
    required this.repeatsWeekly,
  });

  final DateTime date;
  final DayPlan? plan;

  /// A repeat covers this weekday on this date — true even for a day the
  /// user cleared ("just this Thursday"), so editing it can ask "just this
  /// one, or every one?".
  final bool repeatsWeekly;

  factory DayPlanDay.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json['date'] as String);
    final repeats = json['repeats_weekly'] as bool? ?? false;
    final plan = json['plan'] as Map<String, dynamic>?;
    final occasion = DayOccasion.fromWire(plan?['occasion'] as String?);
    final dress = DressLevel.fromWire(plan?['dress_level'] as String?);
    return DayPlanDay(
      date: dayOnly(date),
      // An occasion this build doesn't know reads as unplanned rather than
      // failing the whole week.
      plan: occasion == null
          ? null
          : DayPlan(
              date: dayOnly(date),
              occasion: occasion,
              dress: dress ?? occasion.dress,
              note: plan?['note'] as String? ?? '',
              repeatWeekly: repeats,
              fromRepeat: json['source'] == 'weekly',
            ),
      repeatsWeekly: repeats,
    );
  }
}

/// `GET/PUT/DELETE /today/plans` — Plan your week / Plan a day. Every
/// [DioException] becomes a typed [ApiException].
class DayPlansService {
  DayPlansService(this._dio);

  final Dio _dio;

  /// Each day from [from] to [to] inclusive.
  Future<List<DayPlanDay>> list({
    required DateTime from,
    required DateTime to,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/today/plans',
        queryParameters: {'from': apiDate(from), 'to': apiDate(to)},
      );
      return [
        for (final d in response.data!['days'] as List)
          DayPlanDay.fromJson(d as Map<String, dynamic>),
      ];
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Saves [plan] for its date ([DayPlanScope.day]) or as the weekday's
  /// repeat from that date on ([DayPlanScope.fromNow]). Returns how the day
  /// resolves afterwards.
  Future<DayPlanDay> save(DayPlan plan, {required DayPlanScope scope}) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/today/plans/${apiDate(plan.date)}',
        data: {
          'occasion': plan.occasion.wire,
          'dress_level': plan.dress.wire,
          'note': plan.note.trim().isEmpty ? null : plan.note.trim(),
          'scope': scope.wire,
        },
      );
      return DayPlanDay.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Clears [date] ([DayPlanScope.day]; a repeat carries on next week) or
  /// stops the weekday's repeat from [date] on ([DayPlanScope.fromNow]).
  Future<DayPlanDay> clear(DateTime date, {required DayPlanScope scope}) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/today/plans/${apiDate(date)}',
        queryParameters: {'scope': scope.wire},
      );
      return DayPlanDay.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }
}

final dayPlansServiceProvider = Provider<DayPlansService>((ref) {
  return DayPlansService(ref.read(dioProvider));
});
