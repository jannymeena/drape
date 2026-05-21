import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

enum _Freq { daily, weekly, never }

class NotificationsPreferencesScreen extends StatefulWidget {
  static const path = 'notifications';
  static const name = 'profile_notifications';

  const NotificationsPreferencesScreen({super.key});

  @override
  State<NotificationsPreferencesScreen> createState() =>
      _NotificationsPreferencesScreenState();
}

class _NotificationsPreferencesScreenState
    extends State<NotificationsPreferencesScreen> {
  bool _pushEnabled = true;
  bool _dailyOutfit = true;
  bool _outfitReminders = true;
  bool _shopping = true;
  bool _insights = true;
  bool _quietHours = true;
  bool _weeklySummary = true;
  bool _productDeals = false;
  bool _proOffers = false;
  _Freq _dailyFreq = _Freq.daily;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    'Control when and how DRAPE reaches you',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _ToggleCard(
                    icon: Icons.notifications_outlined,
                    label: 'Enable Push Notifications',
                    value: _pushEnabled,
                    onChanged: (v) => setState(() => _pushEnabled = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('DAILY REMINDERS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.checkroom_outlined,
                    label: 'Daily Outfit Suggestions',
                    subtitle: '7:00 AM in your timezone (Toronto, EDT)',
                    value: _dailyOutfit,
                    onChanged: (v) => setState(() => _dailyOutfit = v),
                    extra: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '[CHANGE TIME]',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.gold,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold,
                                ),
                          ),
                          Text(
                            '7:00 AM',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: _Freq.values
                        .map((f) => _FreqPill(
                              label: f.name.toUpperCase(),
                              selected: _dailyFreq == f,
                              onTap: () => setState(() => _dailyFreq = f),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                  _ToggleCard(
                    icon: Icons.alarm_outlined,
                    label: 'Outfit Reminders',
                    subtitle: 'Remind me to log what I wore (8:00 PM daily)',
                    value: _outfitReminders,
                    onChanged: (v) => setState(() => _outfitReminders = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('SHOPPING'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Shopping Suggestions',
                    subtitle: 'When DRAPE spots a wardrobe gap',
                    value: _shopping,
                    onChanged: (v) => setState(() => _shopping = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('INSIGHTS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.bar_chart,
                    label: 'Wardrobe Insights',
                    subtitle: 'Weekly summary of closet stats',
                    value: _insights,
                    onChanged: (v) => setState(() => _insights = v),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('QUIET HOURS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.nightlight_outlined,
                    label: 'Enable Quiet Hours',
                    value: _quietHours,
                    onChanged: (v) => setState(() => _quietHours = v),
                    extra: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ACTIVE PERIOD',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.taupe,
                                      letterSpacing: 1.2,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              Text(
                                '10:00 PM – 8:00 AM',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text(
                            '[CHANGE]',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.gold,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.gold,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('EMAIL NOTIFICATIONS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.article_outlined,
                    label: 'Weekly Summary',
                    value: _weeklySummary,
                    onChanged: (v) => setState(() => _weeklySummary = v),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.local_offer_outlined,
                    label: 'Product Deals',
                    value: _productDeals,
                    onChanged: (v) => setState(() => _productDeals = v),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.star_outline,
                    label: 'Pro Offers',
                    value: _proOffers,
                    onChanged: (v) => setState(() => _proOffers = v),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton(
                    onPressed: () => debugPrint('notifications: test'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.espresso, width: 1.5),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      'SEND TEST NOTIFICATION',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.espresso,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                          ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Notifications',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.taupe,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _ToggleCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? extra;

  const _ToggleCard({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.onChanged,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryWarm,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.espresso, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: AppColors.espresso,
              ),
            ],
          ),
          ?extra,
        ],
      ),
    );
  }
}

class _FreqPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FreqPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.tanFixed,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected ? AppColors.white : AppColors.inkSoft,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}
