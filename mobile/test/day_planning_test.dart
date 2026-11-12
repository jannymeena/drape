import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/widgets/pipeda_note.dart';
import 'package:mobile/modules/today/day_plans_controller.dart';
import 'package:mobile/modules/today/day_plans_service.dart';
import 'package:mobile/modules/today/models/day_plan.dart';
import 'package:mobile/modules/today/screens/plan_week_screen.dart';
import 'package:mobile/modules/today/widgets/plan_day_sheet.dart';
import 'package:mobile/shared/models/api_error.dart';

import 'support/fake_day_plans_service.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A container whose plans come from [service] (loaded before returning).
Future<ProviderContainer> _container(
  WidgetTester tester,
  DayPlansService service,
) async {
  final container = ProviderContainer(
    overrides: [dayPlansServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  container.read(dayPlansProvider); // starts the load
  await tester.pump();
  return container;
}

/// A button that opens Plan the day for [date]; returns the container so
/// tests can read the saved plans.
Future<ProviderContainer> _pumpSheetHost(
  WidgetTester tester,
  DateTime date, {
  DayPlansService? service,
}) async {
  final container = await _container(tester, service ?? FakeDayPlansService());
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => PlanDaySheet.open(context, ref, date),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  final today = dayOnly(DateTime.now());
  final tomorrow = DateTime(today.year, today.month, today.day + 1);

  testWidgets('Plan the day: pick an occasion, its dress level, then save', (
    tester,
  ) async {
    _tall(tester);
    final service = FakeDayPlansService();
    final container = await _pumpSheetHost(tester, tomorrow, service: service);

    expect(
      find.text(
        '${weekdayLong(tomorrow)}, ${monthShort(tomorrow)} '
        '${tomorrow.day}',
      ),
      findsOneWidget,
    );
    expect(find.text('Repeat every ${weekdayLong(tomorrow)}'), findsOneWidget);
    // No forecast for tomorrow yet → the muted placeholder on the right.
    expect(find.text('Forecast soon'), findsOneWidget);
    // Nothing picked yet → Save does nothing.
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    expect(find.text('Save plan'), findsOneWidget);

    // An interview defaults to Business.
    await tester.tap(find.text('Interview'));
    await tester.pump();
    // No separate pill: the slider's own label is the highlight.
    expect(find.text('Business'), findsOneWidget);
    final business = tester.widget<Text>(find.text('Business'));
    expect(business.style?.fontWeight, FontWeight.w800);
    // Privacy line under Save plan; no tick on the picked tile and no
    // "Set by your event" hint.
    expect(find.text(PipedaNote.text), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(PipedaNote.text)).dy,
      greaterThan(tester.getTopLeft(find.text('Save plan')).dy),
    );
    expect(find.byIcon(Icons.check), findsNothing);
    expect(find.textContaining('Set by your event'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Client pitch');
    await tester.pump();
    expect(find.text('12 / 100'), findsOneWidget);

    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();

    expect(service.calls.last, 'save interview ${apiDate(tomorrow)} day');
    final plan = container.read(dayPlansProvider)[tomorrow]!;
    expect(plan.occasion, DayOccasion.interview);
    expect(plan.dress, DressLevel.business);
    expect(plan.title, 'Interview · Client pitch');
    expect(
      find.text(
        'Planned: Interview, ${weekdayLong(tomorrow)}. '
        'Your outfit will be ready by 10 pm.',
      ),
      findsOneWidget,
    );

    // Undo puts the day back to unplanned.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(service.calls.last, 'clear ${apiDate(tomorrow)} day');
    expect(container.read(dayPlansProvider)[tomorrow], isNull);
  });

  testWidgets(
    'Plan the day: 80% tall, answering scrolls to the next question',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpSheetHost(tester, tomorrow);

      expect(
        tester.getSize(find.byType(PlanDaySheet)).height,
        closeTo(844 * 0.8, 1),
      );

      final sheetTop = tester.getTopLeft(find.byType(PlanDaySheet)).dy;
      final before = tester.getTopLeft(find.text('HOW DRESSED UP?')).dy;
      await tester.tap(find.text('Work day'));
      await tester.pumpAndSettle();
      final after = tester.getTopLeft(find.text('HOW DRESSED UP?')).dy;
      expect(after, lessThan(before));
      // The whole question (label + slider) is on screen above Save plan; it
      // only reaches the very top when there's enough content below it.
      expect(after, greaterThan(sheetTop));
      expect(
        tester.getRect(find.byType(Slider)).bottom,
        lessThan(tester.getTopLeft(find.text('Save plan')).dy),
      );

      // The note is near the end, so the scroll stops at the bottom: it just
      // has to be fully on screen above the Save bar.
      await tester.tap(find.text('Formal'));
      await tester.pumpAndSettle();
      final note = tester.getRect(find.byType(TextField));
      final save = tester.getTopLeft(find.text('Save plan')).dy;
      expect(note.top, greaterThan(sheetTop));
      expect(note.bottom, lessThan(save));
    },
  );

  testWidgets('Plan the day: no close button; tapping outside dismisses', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await _pumpSheetHost(tester, tomorrow);

    expect(find.byTooltip('Close'), findsNothing);
    expect(find.byIcon(Icons.close), findsNothing);

    await tester.tapAt(const Offset(195, 40)); // the barrier above the sheet
    await tester.pumpAndSettle();
    expect(find.byType(PlanDaySheet), findsNothing);
    expect(container.read(dayPlansProvider)[tomorrow], isNull);
  });

  testWidgets('Plan the day: dress labels sit centred under their stops', (
    tester,
  ) async {
    for (final width in [360.0, 390.0, 430.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await _pumpSheetHost(tester, tomorrow);

      final slider = find.byType(Slider);
      final box = tester.renderObject<RenderBox>(slider);
      final base = SliderTheme.of(tester.element(slider));
      // The theme the slider paints with (thumb/overlay come from the sheet).
      final track = const RoundedRectSliderTrackShape().getPreferredRect(
        parentBox: box,
        sliderTheme: base,
        isEnabled: true,
        isDiscrete: true,
      );
      final rect = tester.getRect(slider);
      const n = 5;
      for (final (i, l) in DressLevel.values.indexed) {
        final tick = rect.left + track.left + track.width * i / (n - 1);
        final label = tester.getCenter(find.text(l.label)).dx;
        expect(label, closeTo(tick, 0.5), reason: '${l.label} @ $width');
        // …and stays on screen. (The test font draws every glyph a full
        // em wide, so labels here are far wider than real DM Sans — this
        // only guards against them being pushed off the edge.)
        final labelRect = tester.getRect(find.text(l.label));
        expect(labelRect.left, greaterThanOrEqualTo(0));
        expect(labelRect.right, lessThanOrEqualTo(width));
      }
      Navigator.of(tester.element(slider)).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('Plan the day: an existing plan can be cleared', (tester) async {
    _tall(tester);
    final container = await _pumpSheetHost(
      tester,
      tomorrow,
      service: FakeDayPlansService(
        plans: [
          DayPlan(
            date: tomorrow,
            occasion: DayOccasion.workDay,
            dress: DressLevel.smartCasual,
          ),
        ],
      ),
    );

    // Not a repeating day → no "which days?" question.
    await tester.tap(find.text('Clear plan'));
    await tester.pumpAndSettle();
    expect(container.read(dayPlansProvider)[tomorrow], isNull);
    expect(
      find.text('Plan cleared for ${weekdayLong(tomorrow)}.'),
      findsOneWidget,
    );
  });

  testWidgets('Plan your week: seven rows, presets fill only open days', (
    tester,
  ) async {
    _tall(tester);
    final container = await _container(tester, FakeDayPlansService());
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanWeekScreen()),
      ),
    );

    expect(find.text('Plan your week'), findsOneWidget);
    // Same face as Today's greeting.
    final title = tester.widget<Text>(find.text('Plan your week')).style!;
    expect(title.fontFamily, startsWith('Newsreader'));
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w600);
    // Today is always styled; the other six need a plan.
    expect(find.text('1 of 7 planned'), findsOneWidget);
    expect(find.text('6 days to plan'), findsOneWidget);
    expect(find.text('Add plan'), findsNWidgets(6));
    expect(find.text('Today'), findsOneWidget);
    // No legend, no calendar row, and Done is text only.
    expect(find.textContaining('Filled = planned'), findsNothing);
    expect(find.text('Import from my calendar'), findsNothing);
    expect(find.byIcon(Icons.check), findsNothing);
    // "Add plan" fills the row's middle and matches the date tile's height.
    final addPlan = find
        .ancestor(
          of: find.text('Add plan').first,
          matching: find.byType(SizedBox),
        )
        .first;
    expect(tester.getSize(addPlan).height, 56);
    final row = find
        .ancestor(of: find.text('Add plan').first, matching: find.byType(Row))
        .at(1); // tile · add plan · chevron
    final chevron = tester.getRect(
      find.descendant(of: row, matching: find.byIcon(Icons.chevron_right)),
    );
    // From the date tile (56 + 12 gap) to just before the chevron (8 gap).
    expect(tester.getRect(addPlan).right, closeTo(chevron.left - 8, 0.5));

    await tester.tap(find.text('Weekend: Day off'));
    await tester.pumpAndSettle();
    final days = nextSevenDays();
    final weekendAhead = days
        .skip(1)
        .where((d) => d.weekday >= DateTime.saturday)
        .length;
    final plans = container.read(dayPlansProvider);
    for (final d in days) {
      final isWeekend = d.weekday >= DateTime.saturday;
      expect(plans[d]?.occasion, isWeekend ? DayOccasion.dayOff : null);
    }
    // Rows reflect it: each planned upcoming weekend day loses its Add plan.
    final todayIsWeekend = days.first.weekday >= DateTime.saturday;
    expect(find.text('Add plan'), findsNWidgets(6 - weekendAhead));
    expect(
      find.text('Day off'),
      findsNWidgets(weekendAhead + (todayIsWeekend ? 1 : 0)),
    );
  });

  group('repeats', () {
    final weekday = weekdayLong(tomorrow);
    final repeat = DayPlan(
      date: tomorrow,
      occasion: DayOccasion.workDay,
      dress: DressLevel.smartCasual,
    );

    /// Tomorrow's weekday has repeated Work day for three weeks.
    FakeDayPlansService repeating() => FakeDayPlansService()
      ..addRepeat(
        repeat,
        startsOn: DateTime(tomorrow.year, tomorrow.month, tomorrow.day - 21),
      );

    Future<void> pickDayOff(WidgetTester tester) async {
      await tester.tap(find.text('Day off'));
      await tester.pumpAndSettle();
    }

    testWidgets('a repeat loads into the sheet: plan + switch on', (
      tester,
    ) async {
      _tall(tester);
      await _pumpSheetHost(tester, tomorrow, service: repeating());
      final sheet = tester.widget<PlanDaySheet>(find.byType(PlanDaySheet));
      expect(sheet.existing?.occasion, DayOccasion.workDay);
      expect(sheet.existing?.fromRepeat, isTrue);
      expect(sheet.repeats, isTrue);
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    });

    testWidgets('switching repeat on for a new day saves from now on', (
      tester,
    ) async {
      _tall(tester);
      final service = FakeDayPlansService();
      await _pumpSheetHost(tester, tomorrow, service: service);
      await tester.tap(find.text('Work day'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();

      expect(find.text('Which ${weekday}s?'), findsNothing); // nothing to ask
      expect(
        service.calls,
        contains('save work_day ${apiDate(tomorrow)} from_now'),
      );
      expect(find.text('Planned: Work day, every $weekday.'), findsOneWidget);
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('"Just this <weekday>" changes one day, repeat stays', (
      tester,
    ) async {
      _tall(tester);
      final service = repeating();
      final container = await _pumpSheetHost(
        tester,
        tomorrow,
        service: service,
      );
      await pickDayOff(tester);
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();

      expect(find.text('Which ${weekday}s?'), findsOneWidget);
      expect(find.text('Every $weekday from now on'), findsOneWidget);
      await tester.tap(find.text('Just this $weekday'));
      await tester.pumpAndSettle();

      expect(service.calls.last, 'save day_off ${apiDate(tomorrow)} day');
      final plan = container.read(dayPlansProvider)[tomorrow]!;
      expect(plan.occasion, DayOccasion.dayOff);
      expect(plan.fromRepeat, isFalse);
      expect(
        container.read(dayPlansProvider.notifier).repeats(tomorrow),
        isTrue,
      );
      // It replaced a repeat day, which can't be put back exactly → no Undo.
      expect(find.text('Undo'), findsNothing);
    });

    testWidgets('"Every <weekday> from now on" changes the repeat', (
      tester,
    ) async {
      _tall(tester);
      final service = repeating();
      final container = await _pumpSheetHost(
        tester,
        tomorrow,
        service: service,
      );
      await pickDayOff(tester);
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Every $weekday from now on'));
      await tester.pumpAndSettle();

      expect(
        service.calls,
        contains('save day_off ${apiDate(tomorrow)} from_now'),
      );
      expect(service.calls.last, startsWith('list ')); // the week reloads
      final plan = container.read(dayPlansProvider)[tomorrow]!;
      expect(plan.occasion, DayOccasion.dayOff);
      expect(plan.fromRepeat, isTrue);
      expect(find.text('Planned: Day off, every $weekday.'), findsOneWidget);

      // The weeks before still show the old repeat.
      final past = await service.list(
        from: DateTime(tomorrow.year, tomorrow.month, tomorrow.day - 7),
        to: DateTime(tomorrow.year, tomorrow.month, tomorrow.day - 7),
      );
      expect(past.single.plan?.occasion, DayOccasion.workDay);
    });

    testWidgets('dismissing the question goes back to the plan, edits kept', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = repeating();
      await _pumpSheetHost(tester, tomorrow, service: service);
      await pickDayOff(tester);
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();
      expect(find.text('Which ${weekday}s?'), findsOneWidget);

      await tester.tapAt(const Offset(195, 40)); // the scrim
      await tester.pumpAndSettle();
      expect(find.text('Which ${weekday}s?'), findsNothing);
      expect(find.byType(PlanDaySheet), findsOneWidget);
      expect(service.calls.where((c) => c.startsWith('save')), isEmpty);
      // Day off is still the pick: its default dress level is highlighted.
      expect(
        tester.widget<Text>(find.text('Casual')).style?.fontWeight,
        FontWeight.w800,
      );
    });

    testWidgets('turning repeat off stops it and keeps this day', (
      tester,
    ) async {
      _tall(tester);
      final service = repeating();
      final container = await _pumpSheetHost(
        tester,
        tomorrow,
        service: service,
      );
      await tester.tap(find.byType(Switch));
      await tester.pump();
      await tester.tap(find.text('Save plan'));
      await tester.pumpAndSettle();

      expect(find.text('Which ${weekday}s?'), findsNothing);
      expect(service.calls, [
        'list ${apiDate(today)} ${apiDate(nextSevenDays().last)}',
        'clear ${apiDate(tomorrow)} from_now',
        'save work_day ${apiDate(tomorrow)} day',
      ]);
      expect(container.read(dayPlansProvider)[tomorrow]?.fromRepeat, isFalse);
      expect(
        container.read(dayPlansProvider.notifier).repeats(tomorrow),
        isFalse,
      );
      expect(
        find.text('Planned: Work day, $weekday. $weekday repeat stopped.'),
        findsOneWidget,
      );
    });

    testWidgets('Clear → "Just this <weekday>" skips one day', (tester) async {
      _tall(tester);
      final service = repeating();
      final container = await _pumpSheetHost(
        tester,
        tomorrow,
        service: service,
      );
      await tester.tap(find.text('Clear plan'));
      await tester.pumpAndSettle();
      expect(find.text('Stop repeating'), findsOneWidget);
      await tester.tap(find.text('Just this $weekday'));
      await tester.pumpAndSettle();

      expect(service.calls.last, 'clear ${apiDate(tomorrow)} day');
      expect(container.read(dayPlansProvider)[tomorrow], isNull);
      // Still a repeating day — the next edit asks again.
      expect(
        container.read(dayPlansProvider.notifier).repeats(tomorrow),
        isTrue,
      );
      expect(find.text('Plan cleared for $weekday.'), findsOneWidget);
    });

    testWidgets('Clear → "Stop repeating" ends the repeat', (tester) async {
      _tall(tester);
      final service = repeating();
      final container = await _pumpSheetHost(
        tester,
        tomorrow,
        service: service,
      );
      await tester.tap(find.text('Clear plan'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stop repeating'));
      await tester.pumpAndSettle();

      expect(service.calls, contains('clear ${apiDate(tomorrow)} from_now'));
      expect(container.read(dayPlansProvider)[tomorrow], isNull);
      expect(
        container.read(dayPlansProvider.notifier).repeats(tomorrow),
        isFalse,
      );
      expect(find.text('$weekday repeat stopped.'), findsOneWidget);
    });

    testWidgets('presets skip a repeating day the user cleared', (
      tester,
    ) async {
      final service = repeating();
      final container = await _container(tester, service);
      await container.read(dayPlansProvider.notifier).clear(tomorrow);
      final filled = await container
          .read(dayPlansProvider.notifier)
          .fill(
            nextSevenDays(),
            when: (_) => true,
            occasion: DayOccasion.dayOff,
          );
      expect(filled, 6); // every day but tomorrow, which the user cleared
      expect(container.read(dayPlansProvider)[tomorrow], isNull);
    });
  });

  testWidgets('a failed save shows the server message', (tester) async {
    _tall(tester);
    await _pumpSheetHost(tester, tomorrow, service: _FailingService());
    await tester.tap(find.text('Work day'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save plan'));
    await tester.pumpAndSettle();
    expect(find.text("Past days can't be changed."), findsOneWidget);
  });

  test('API values match the backend', () {
    expect(DayOccasion.values.map((o) => o.wire), [
      'work_day',
      'remote_day',
      'day_off',
      'official_meeting',
      'school',
      'interview',
      'date_dinner',
      'formal_event',
      'travel',
      'workout',
      'friends',
      'other',
    ]);
    expect(DressLevel.values.map((l) => l.wire), [
      'athleisure',
      'casual',
      'smart_casual',
      'business',
      'formal',
    ]);
    expect(apiDate(DateTime(2026, 3, 5)), '2026-03-05');
  });

  test('a day parses from the API', () {
    final day = DayPlanDay.fromJson({
      'date': '2026-11-19',
      'plan': {
        'occasion': 'official_meeting',
        'dress_level': 'business',
        'note': 'Board review',
      },
      'source': 'weekly',
      'repeats_weekly': true,
    });
    expect(day.date, DateTime(2026, 11, 19));
    expect(day.repeatsWeekly, isTrue);
    expect(day.plan!.occasion, DayOccasion.officialMeeting);
    expect(day.plan!.dress, DressLevel.business);
    expect(day.plan!.note, 'Board review');
    expect(day.plan!.fromRepeat, isTrue);

    final skipped = DayPlanDay.fromJson({
      'date': '2026-11-19',
      'plan': null,
      'source': null,
      'repeats_weekly': true,
    });
    expect(skipped.plan, isNull);
    expect(skipped.repeatsWeekly, isTrue);
  });

  test('readyLabel follows the evening-before rule', () {
    expect(readyLabel(today), 'Ready now');
    expect(readyLabel(tomorrow), 'Ready by 10 pm');
    expect(
      readyLabel(DateTime(today.year, today.month, today.day + 3)),
      'Ready the night before',
    );
  });
}

class _FailingService extends FakeDayPlansService {
  @override
  Future<DayPlanDay> save(DayPlan plan, {required DayPlanScope scope}) async =>
      throw const ApiException(
        code: 'past_date',
        message: "Past days can't be changed.",
        statusCode: 422,
      );
}
