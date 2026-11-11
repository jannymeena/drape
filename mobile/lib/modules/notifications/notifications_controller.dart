import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/session_epoch.dart';
import 'models/app_notification.dart';

/// The Notifications feed, newest first.
///
/// UI-only for now: there is no feed endpoint yet (BACKEND_CHANGES 1.0), so
/// debug builds start with a sample feed to review the screen and release
/// builds start empty ("All caught up") — no made-up notifications ever
/// reach TestFlight. Read state lives in memory for the session.
class NotificationsController extends StateNotifier<List<AppNotification>> {
  NotificationsController(super.initial);

  int get unreadCount => state.where((n) => n.unread).length;

  void markRead(String id) {
    state = [for (final n in state) n.id == id ? n.copyWith(unread: false) : n];
  }

  void markAllRead() {
    state = [for (final n in state) n.copyWith(unread: false)];
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsController, List<AppNotification>>((
      ref,
    ) {
      ref.watch(sessionEpochProvider); // user-scoped
      return NotificationsController(
        kDebugMode ? sampleNotifications(DateTime.now()) : const [],
      );
    });

/// Unread count for the bell's dot on Today.
final unreadNotificationsProvider = Provider<int>(
  (ref) => ref.watch(notificationsProvider).where((n) => n.unread).length,
);

/// The Stitch mock's feed, dated relative to [now] so it groups the same way
/// on any day: two unread today, three read earlier this week.
@visibleForTesting
List<AppNotification> sampleNotifications(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  // Today's items sit just before "now" (never in the future).
  DateTime todayAt(int hour, int minute, Duration fallback) {
    final t = today.add(Duration(hours: hour, minutes: minute));
    final alt = now.subtract(fallback);
    final pick = t.isBefore(now) ? t : alt;
    return pick.isBefore(today) ? today : pick;
  }

  DateTime daysAgo(int days, int hour, int minute) =>
      DateTime(today.year, today.month, today.day - days, hour, minute);

  return [
    AppNotification(
      id: 'weather',
      kind: NotificationKind.weather,
      title: 'Rain from 5 pm',
      body: 'Your Rainy-day layers outfit is rain-ready. Tap to see it.',
      at: todayAt(7, 30, const Duration(minutes: 20)),
      unread: true,
    ),
    AppNotification(
      id: 'wrapped',
      kind: NotificationKind.wrapped,
      title: 'Your Wardrobe Wrapped is ready',
      body: 'See how you wore your clothes this month.',
      at: todayAt(7, 0, const Duration(minutes: 50)),
      unread: true,
    ),
    AppNotification(
      id: 'plan',
      kind: NotificationKind.planTomorrow,
      title: 'Plan tomorrow?',
      body: 'Tell Zoura what is on and wake up to your outfit.',
      at: daysAgo(1, 20, 0),
    ),
    AppNotification(
      id: 'streak',
      kind: NotificationKind.streak,
      title: '14-day streak!',
      body: 'You have logged an outfit every day for two weeks.',
      at: daysAgo(1, 21, 5),
    ),
    AppNotification(
      id: 'referral',
      kind: NotificationKind.referral,
      title: 'Maya joined with your link',
      body: '6 of 10 friends activated. Four more for a free month of Pro.',
      at: daysAgo(2, 18, 0),
      progress: 6,
      progressTotal: 10,
      progressLabel: 'Tier progress',
    ),
  ];
}
