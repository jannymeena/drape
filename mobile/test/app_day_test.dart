import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/day_plan.dart';
import 'package:mobile/shared/services/dio_service.dart';

void main() {
  test('the app day rolls over at 05:00, like the backend', () {
    expect(appToday(DateTime(2026, 11, 24, 0, 30)), DateTime(2026, 11, 23));
    expect(appToday(DateTime(2026, 11, 24, 4, 59)), DateTime(2026, 11, 23));
    expect(appToday(DateTime(2026, 11, 24, 5)), DateTime(2026, 11, 24));
    expect(daysFromToday(DateTime(2026, 11, 23), DateTime(2026, 11, 24, 1)), 0);
    expect(nextSevenDays(DateTime(2026, 11, 24, 1)).first, DateTime(2026, 11, 23));
  });

  test('the timezone header is the UTC offset the backend parses', () {
    expect(utcOffsetHeader(const Duration(hours: 5, minutes: 30)), '+05:30');
    expect(utcOffsetHeader(const Duration(hours: -4)), '-04:00');
    expect(utcOffsetHeader(Duration.zero), '+00:00');
    expect(utcOffsetHeader(const Duration(hours: -9, minutes: -30)), '-09:30');
  });
}
