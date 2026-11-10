import 'package:flutter/material.dart';

/// "How dressed up?" — the 5-stop slider on Plan the day. Mirrors the
/// backend `DayFormality` literal (athleisure … formal).
enum DressLevel {
  athleisure('Athleisure'),
  casual('Casual'),
  smartCasual('Smart casual'),
  business('Business'),
  formal('Formal');

  const DressLevel(this.label);
  final String label;
}

/// "What is on" — one per day. Each sets a default [dress] level the user
/// can override ("Set by your event. Change it if you like.").
enum DayOccasion {
  workDay('Work day', Icons.work_outline, DressLevel.smartCasual),
  remoteDay('Remote day', Icons.laptop_mac, DressLevel.casual),
  dayOff('Day off', Icons.coffee_outlined, DressLevel.casual),
  officialMeeting('Official meeting', Icons.corporate_fare, DressLevel.business),
  school("School or parents' meeting", Icons.groups_outlined, DressLevel.smartCasual),
  interview('Interview', Icons.badge_outlined, DressLevel.business),
  dateDinner('Date or dinner', Icons.wine_bar_outlined, DressLevel.smartCasual),
  formalEvent('Wedding or formal event', Icons.auto_awesome_outlined, DressLevel.formal),
  travel('Travel day', Icons.flight, DressLevel.casual),
  workout('Workout', Icons.fitness_center, DressLevel.athleisure),
  friends('Time with friends', Icons.forum_outlined, DressLevel.casual),
  other('Other', Icons.more_horiz, DressLevel.smartCasual);

  const DayOccasion(this.label, this.icon, this.dress);
  final String label;
  final IconData icon;

  /// Default dress level for this occasion.
  final DressLevel dress;
}

/// What the user told us about one day. UI-only for now (held in memory by
/// `dayPlansProvider`); the shape is what the day-plans API will carry.
class DayPlan {
  const DayPlan({
    required this.date,
    required this.occasion,
    required this.dress,
    this.note = '',
    this.repeatWeekly = false,
  });

  /// Local calendar day (time stripped — see [dayOnly]).
  final DateTime date;
  final DayOccasion occasion;
  final DressLevel dress;

  /// "Anything else?" — up to 100 chars.
  final String note;

  /// "Repeat every `weekday`" — use as the default for that weekday.
  final bool repeatWeekly;

  /// "Work day · Client pitch" — the chip text on Plan your week.
  String get title => note.isEmpty ? occasion.label : '${occasion.label} · $note';

  DayPlan copyWith({DateTime? date}) => DayPlan(
        date: date ?? this.date,
        occasion: occasion,
        dress: dress,
        note: note,
        repeatWeekly: repeatWeekly,
      );
}

// ─── Date helpers shared by the Today planning UI ─────────────────────────

const _weekdaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdaysLong = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
const _monthsShort = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "Wed".
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// "Wednesday".
String weekdayLong(DateTime d) => _weekdaysLong[d.weekday - 1];

/// "Nov".
String monthShort(DateTime d) => _monthsShort[d.month - 1];

/// The next seven days, today first.
List<DateTime> nextSevenDays([DateTime? now]) {
  final today = dayOnly(now ?? DateTime.now());
  return [
    for (var i = 0; i < 7; i++) DateTime(today.year, today.month, today.day + i),
  ];
}

/// Days from today (0 = today, 1 = tomorrow).
int daysFromToday(DateTime date, [DateTime? now]) =>
    dayOnly(date).difference(dayOnly(now ?? DateTime.now())).inDays;

/// When the outfit for [date] will be ready — outfits are styled the evening
/// before ("Ready now" / "Ready by 10 pm" / "Ready the night before").
String readyLabel(DateTime date, {DateTime? now}) {
  final d = daysFromToday(date, now);
  if (d <= 0) return 'Ready now';
  if (d == 1) return 'Ready by 10 pm';
  return 'Ready the night before';
}
