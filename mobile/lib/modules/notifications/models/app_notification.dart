import 'package:flutter/material.dart';

/// What a notification is about — drives its icon and action button.
enum NotificationKind {
  /// Weather change for today's outfit ("Rain from 5 pm"). Tap → Today.
  weather(Icons.umbrella_outlined, null),

  /// Monthly "Wardrobe Wrapped" recap.
  wrapped(Icons.auto_awesome_outlined, 'See it'),

  /// Evening nudge to plan tomorrow.
  planTomorrow(Icons.calendar_today_outlined, 'Plan'),

  /// Logging-streak milestone.
  streak(Icons.local_fire_department_outlined, 'Share'),

  /// Referral progress ("6 of 10 friends activated").
  referral(Icons.card_giftcard_outlined, 'Invite more');

  const NotificationKind(this.icon, this.actionLabel);
  final IconData icon;

  /// The outlined button under the body; null = the whole card is the action.
  final String? actionLabel;
}

/// One entry in the Notifications feed. UI-only for now (in-memory, see
/// `notificationsProvider`); the shape is what the feed API will carry.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.unread = false,
    this.progress,
    this.progressTotal,
    this.progressLabel,
  });

  final String id;
  final NotificationKind kind;
  final String title;
  final String body;
  final DateTime at;
  final bool unread;

  /// Optional progress bar (referral tier): [progress] of [progressTotal],
  /// captioned [progressLabel] ("Tier progress").
  final int? progress;
  final int? progressTotal;
  final String? progressLabel;

  AppNotification copyWith({bool? unread}) => AppNotification(
    id: id,
    kind: kind,
    title: title,
    body: body,
    at: at,
    unread: unread ?? this.unread,
    progress: progress,
    progressTotal: progressTotal,
    progressLabel: progressLabel,
  );
}
