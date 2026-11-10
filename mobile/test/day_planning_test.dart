import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/widgets/pipeda_note.dart';
import 'package:mobile/modules/today/day_plans_controller.dart';
import 'package:mobile/modules/today/models/day_plan.dart';
import 'package:mobile/modules/today/screens/plan_week_screen.dart';
import 'package:mobile/modules/today/widgets/plan_day_sheet.dart';

void _tall(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// A button that opens Plan the day for [date]; returns the container so
/// tests can read the saved plans.
Future<ProviderContainer> _pumpSheetHost(
  WidgetTester tester,
  DateTime date,
) async {
  final container = ProviderContainer();
  addTearDown(container.dispose);
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
    final container = await _pumpSheetHost(tester, tomorrow);

    expect(find.text('${weekdayLong(tomorrow)}, ${monthShort(tomorrow)} '
        '${tomorrow.day}'), findsOneWidget);
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

    final plan = container.read(dayPlansProvider)[tomorrow]!;
    expect(plan.occasion, DayOccasion.interview);
    expect(plan.dress, DressLevel.business);
    expect(plan.title, 'Interview · Client pitch');
    expect(
      find.text('Planned: Interview, ${weekdayLong(tomorrow)}. '
          'Your outfit will be ready by 10 pm.'),
      findsOneWidget,
    );

    // Undo puts the day back to unplanned.
    await tester.tap(find.text('Undo'));
    await tester.pump();
    expect(container.read(dayPlansProvider)[tomorrow], isNull);
  });

  testWidgets('Plan the day: 80% tall, answering scrolls to the next question',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _pumpSheetHost(tester, tomorrow);

    expect(tester.getSize(find.byType(PlanDaySheet)).height,
        closeTo(844 * 0.8, 1));

    final sheetTop = tester.getTopLeft(find.byType(PlanDaySheet)).dy;
    final before = tester.getTopLeft(find.text('HOW DRESSED UP?')).dy;
    await tester.tap(find.text('Work day'));
    await tester.pumpAndSettle();
    final after = tester.getTopLeft(find.text('HOW DRESSED UP?')).dy;
    expect(after, lessThan(before));
    // The whole question (label + slider) is on screen above Save plan; it
    // only reaches the very top when there's enough content below it.
    expect(after, greaterThan(sheetTop));
    expect(tester.getRect(find.byType(Slider)).bottom,
        lessThan(tester.getTopLeft(find.text('Save plan')).dy));

    // The note is near the end, so the scroll stops at the bottom: it just
    // has to be fully on screen above the Save bar.
    await tester.tap(find.text('Formal'));
    await tester.pumpAndSettle();
    final note = tester.getRect(find.byType(TextField));
    final save = tester.getTopLeft(find.text('Save plan')).dy;
    expect(note.top, greaterThan(sheetTop));
    expect(note.bottom, lessThan(save));
  });

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
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dayPlansProvider.notifier).save(DayPlan(
          date: tomorrow,
          occasion: DayOccasion.workDay,
          dress: DressLevel.smartCasual,
        ));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Consumer(
              builder: (context, ref, _) => TextButton(
                onPressed: () => PlanDaySheet.open(context, ref, tomorrow),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear plan'));
    await tester.pumpAndSettle();
    expect(container.read(dayPlansProvider)[tomorrow], isNull);
    expect(find.text('Plan cleared for ${weekdayLong(tomorrow)}.'), findsOneWidget);
  });

  testWidgets('Plan your week: seven rows, presets fill only open days', (
    tester,
  ) async {
    _tall(tester);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: PlanWeekScreen()),
      ),
    );

    expect(find.text('Plan your week'), findsOneWidget);
    // Today is always styled; the other six need a plan.
    expect(find.text('1 of 7 planned'), findsOneWidget);
    expect(find.text('6 days to plan'), findsOneWidget);
    expect(find.text('Add plan'), findsNWidgets(6));
    expect(find.text('Today'), findsOneWidget);

    await tester.tap(find.text('Weekend: Day off'));
    await tester.pump();
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
    expect(find.text('Day off'), findsNWidgets(weekendAhead + (todayIsWeekend ? 1 : 0)));
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
