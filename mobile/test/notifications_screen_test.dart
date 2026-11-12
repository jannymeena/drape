import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/notifications/models/app_notification.dart';
import 'package:mobile/modules/notifications/notifications_controller.dart';
import 'package:mobile/modules/notifications/screens/notifications_screen.dart';
import 'package:mobile/modules/today/day_plans_service.dart';
import 'package:mobile/modules/today/widgets/plan_day_sheet.dart';

import 'support/fake_day_plans_service.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  List<AppNotification>? feed,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      dayPlansServiceProvider.overrideWithValue(FakeDayPlansService()),
      notificationsProvider.overrideWith(
        (ref) => NotificationsController(
          feed ?? sampleNotifications(DateTime.now()),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: NotificationsScreen()),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('groups the feed and counts unread', (tester) async {
    await _pump(tester);

    expect(find.text('Notifications'), findsOneWidget);
    // Same title style as "Plan your week": Newsreader 24, semibold, upright.
    final title = tester.widget<Text>(find.text('Notifications')).style!;
    expect(title.fontFamily, startsWith('Newsreader'));
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w600);
    expect(title.fontStyle, isNot(FontStyle.italic));
    // No "Atelier Updates · N new · month" line and no sign-off footer.
    expect(find.text('Atelier Updates'), findsNothing);
    expect(find.textContaining(RegExp(r'\d+ new')), findsNothing);
    expect(find.textContaining('Zoura Atelier'), findsNothing);
    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('EARLIER THIS WEEK'), findsOneWidget);
    expect(find.text('Rain from 5 pm'), findsOneWidget);
    expect(find.text('Maya joined with your link'), findsOneWidget);
    expect(find.text('6 / 10 friends'), findsOneWidget);
    for (final a in ['See it', 'Plan', 'Share', 'Invite more']) {
      expect(find.text(a), findsOneWidget, reason: a);
    }

    // Today's items come first, newest first.
    final rain = tester.getTopLeft(find.text('Rain from 5 pm')).dy;
    final plan = tester.getTopLeft(find.text('Plan tomorrow?')).dy;
    expect(rain, lessThan(plan));
  });

  testWidgets('Mark all read clears the badge and the button', (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.text('Mark all read'));
    await tester.pump();

    expect(find.text('Mark all read'), findsNothing);
    expect(container.read(unreadNotificationsProvider), 0);
  });

  testWidgets('an action marks its card read', (tester) async {
    final container = await _pump(tester);
    expect(container.read(unreadNotificationsProvider), 2);

    await tester.tap(find.text('See it'));
    await tester.pump();

    expect(container.read(unreadNotificationsProvider), 1);
    expect(find.text('Wardrobe Wrapped is coming soon.'), findsOneWidget);
  });

  testWidgets('Plan opens Plan the day for tomorrow', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();

    expect(find.byType(PlanDaySheet), findsOneWidget);
    final sheet = tester.widget<PlanDaySheet>(find.byType(PlanDaySheet));
    final now = DateTime.now();
    expect(sheet.date, DateTime(now.year, now.month, now.day + 1));
  });

  testWidgets('empty feed shows the caught-up state', (tester) async {
    await _pump(tester, feed: const []);

    expect(find.text("You're all caught up"), findsOneWidget);
    expect(find.text('TODAY'), findsNothing);
  });
}
