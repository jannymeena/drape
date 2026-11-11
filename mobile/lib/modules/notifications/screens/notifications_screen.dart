import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/titled_screen_header.dart';
import '../../profile/screens/notifications_preferences_screen.dart';
import '../../profile/screens/profile_intelligence_screen.dart';
import '../../today/models/day_plan.dart';
import '../../today/widgets/plan_day_sheet.dart';
import '../models/app_notification.dart';
import '../notifications_controller.dart';

/// Notifications (Stitch `notifications_zoura`): grouped Today / Earlier
/// this week / Earlier, unread cards raised, "Mark all read", and an action
/// button per kind. Opened from the bell
/// on Today. UI-only — the feed is in memory (see [notificationsProvider]).
class NotificationsScreen extends ConsumerWidget {
  static const path = 'notifications';
  static const name = 'today_notifications';

  const NotificationsScreen({super.key});

  static const _gutter = 24.0;

  void _open(BuildContext context, WidgetRef ref, AppNotification n) {
    ref.read(notificationsProvider.notifier).markRead(n.id);
    switch (n.kind) {
      case NotificationKind.weather:
        // "Tap to see it" — today's outfit is on Today.
        Navigator.of(context).maybePop();
      case NotificationKind.planTomorrow:
        final now = DateTime.now();
        PlanDaySheet.open(
          context,
          ref,
          DateTime(now.year, now.month, now.day + 1),
        );
      case NotificationKind.wrapped:
        _comingSoon(context, 'Wardrobe Wrapped');
      case NotificationKind.streak:
        _comingSoon(context, 'Sharing your streak');
      case NotificationKind.referral:
        _comingSoon(context, 'Inviting friends');
    }
  }

  void _comingSoon(BuildContext context, String what) => showDrapeToast(
    context,
    '$what is coming soon.',
    icon: Icons.schedule,
    background: AppColors.espressoDeep,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(notificationsProvider);
    final unread = feed.where((n) => n.unread).length;
    final groups = _group(feed, DateTime.now());
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            TitledScreenHeader(
              title: 'Notifications',
              onBack: () => Navigator.of(context).maybePop(),
              actionIcon: Icons.settings_outlined,
              actionTooltip: 'Notification settings',
              onAction: () =>
                  context.goNamed(NotificationsPreferencesScreen.name),
              onProfile: () => context.goNamed(ProfileIntelligenceScreen.name),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(_gutter, 8, _gutter, 48),
                children: [
                  if (feed.isEmpty) const _AllCaughtUp(),
                  for (final (i, g) in groups.indexed) ...[
                    _GroupHeader(
                      label: g.label,
                      // "Mark all read" rides on the first group's header.
                      onMarkAllRead: i == 0 && unread > 0
                          ? () => ref
                                .read(notificationsProvider.notifier)
                                .markAllRead()
                          : null,
                    ),
                    const SizedBox(height: 4),
                    for (final n in g.items) ...[
                      _NotificationCard(
                        notification: n,
                        time: _timeLabel(n.at, now),
                        onTap: () => _open(context, ref, n),
                      ),
                      const SizedBox(height: 12),
                    ],
                    const SizedBox(height: 20),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Today / Earlier this week (last 7 days) / Earlier, newest first.
  static List<({String label, List<AppNotification> items})> _group(
    List<AppNotification> feed,
    DateTime now,
  ) {
    final sorted = [...feed]..sort((a, b) => b.at.compareTo(a.at));
    final today = <AppNotification>[];
    final week = <AppNotification>[];
    final older = <AppNotification>[];
    for (final n in sorted) {
      final d = daysFromToday(n.at, now);
      if (d == 0) {
        today.add(n);
      } else if (d >= -6) {
        week.add(n);
      } else {
        older.add(n);
      }
    }
    return [
      if (today.isNotEmpty) (label: 'Today', items: today),
      if (week.isNotEmpty) (label: 'Earlier this week', items: week),
      if (older.isNotEmpty) (label: 'Earlier', items: older),
    ];
  }

  /// "7:30 am" today, "Tue 8:00 pm" this week, "Nov 3" before that.
  static String _timeLabel(DateTime at, DateTime now) {
    final d = daysFromToday(at, now);
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final clock =
        '$h:${at.minute.toString().padLeft(2, '0')} ${at.hour < 12 ? 'am' : 'pm'}';
    if (d == 0) return clock;
    if (d >= -6) return '${weekdayShort(at)} $clock';
    return '${monthShort(at)} ${at.day}';
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final VoidCallback? onMarkAllRead;
  const _GroupHeader({required this.label, this.onMarkAllRead});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: text.labelMedium?.copyWith(
                color: AppColors.inkSoft,
                letterSpacing: 1.7,
              ),
            ),
          ),
          if (onMarkAllRead != null)
            TextButton(
              onPressed: onMarkAllRead,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.espresso,
                padding: const EdgeInsets.only(left: 12),
                minimumSize: const Size(48, 48),
              ),
              child: Text(
                'Mark all read',
                style: text.labelMedium?.copyWith(color: AppColors.espresso),
              ),
            ),
        ],
      ),
    );
  }
}

/// Unread: white and softly raised. Read: flat warm ivory.
class _NotificationCard extends StatelessWidget {
  final AppNotification notification;
  final String time;
  final VoidCallback onTap;
  const _NotificationCard({
    required this.notification,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final text = Theme.of(context).textTheme;
    final action = n.kind.actionLabel;
    return Semantics(
      container: true,
      label: n.unread ? 'Unread' : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: n.unread ? AppColors.white : AppColors.ivoryDim,
          borderRadius: BorderRadius.circular(20),
          boxShadow: n.unread
              ? const [
                  BoxShadow(
                    color: Color(0x0F512F1B),
                    blurRadius: 12,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            // Cards with a button act through the button; the rest (weather)
            // are tappable whole.
            onTap: action == null ? onTap : null,
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: const BoxDecoration(
                          color: AppColors.ivoryWarm,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          n.kind.icon,
                          size: 20,
                          color: AppColors.espresso,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    n.title,
                                    style: text.titleSmall?.copyWith(
                                      fontSize: 15,
                                      color: AppColors.ink,
                                      letterSpacing: -0.2,
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(
                                    time,
                                    style: text.bodySmall?.copyWith(
                                      color: AppColors.taupe,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              n.body,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium?.copyWith(
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                            if (n.progress != null &&
                                n.progressTotal != null) ...[
                              const SizedBox(height: 12),
                              _Progress(notification: n),
                            ],
                            if (action != null) ...[
                              const SizedBox(height: 14),
                              _OutlinedAction(
                                label: action,
                                filledBackground: n.unread,
                                onTap: onTap,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  final AppNotification notification;
  const _Progress({required this.notification});

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final text = Theme.of(context).textTheme;
    final small = text.bodySmall?.copyWith(
      fontSize: 11,
      color: AppColors.taupe,
      fontWeight: FontWeight.w500,
    );
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(n.progressLabel ?? '', style: small)),
            Text(
              '${n.progress} / ${n.progressTotal} friends',
              style: small?.copyWith(
                color: AppColors.espresso,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: n.progress! / n.progressTotal!,
            minHeight: 4,
            backgroundColor: AppColors.sand,
            valueColor: const AlwaysStoppedAnimation(AppColors.espresso),
          ),
        ),
      ],
    );
  }
}

/// Outlined pill button ("See it", "Plan", "Share", "Invite more").
class _OutlinedAction extends StatelessWidget {
  final String label;
  final bool filledBackground;
  final VoidCallback onTap;
  const _OutlinedAction({
    required this.label,
    required this.filledBackground,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filledBackground ? AppColors.ivoryDim : Colors.transparent,
      shape: const StadiumBorder(
        side: BorderSide(color: AppColors.espresso, width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const StadiumBorder(),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          alignment: Alignment.center,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.espresso,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.ivoryWarm,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none,
              size: 28,
              color: AppColors.espresso,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            "You're all caught up",
            style: text.titleMedium?.copyWith(color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Weather changes, plans and milestones will show up here.',
            textAlign: TextAlign.center,
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }
}
