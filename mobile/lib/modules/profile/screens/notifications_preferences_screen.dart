import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/app_settings.dart';
import '../settings_service.dart';

enum _Freq { daily, weekly, never }

class NotificationsPreferencesScreen extends ConsumerStatefulWidget {
  static const path = 'notifications';
  static const name = 'profile_notifications';

  const NotificationsPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationsPreferencesScreen> createState() =>
      _NotificationsPreferencesScreenState();
}

class _NotificationsPreferencesScreenState
    extends ConsumerState<NotificationsPreferencesScreen> {
  bool _pushEnabled = true;
  bool _dailyOutfit = true;
  bool _outfitReminders = true;
  bool _shopping = true;
  bool _insights = true;
  bool _quietHours = false;
  bool _weeklySummary = true;
  bool _productDeals = false;
  bool _proOffers = false;
  // No backend field — local/cosmetic until push scheduling (11d) lands.
  _Freq _dailyFreq = _Freq.daily;

  bool _seeded = false;

  void _seedOnce(AppSettings s) {
    if (_seeded) return;
    _seeded = true;
    _pushEnabled = s.pushEnabled;
    _dailyOutfit = s.dailyOutfitSuggestions;
    _outfitReminders = s.outfitReminders;
    _shopping = s.shoppingSuggestions;
    _insights = s.wardrobeInsights;
    _quietHours = s.quietHoursEnabled;
    _weeklySummary = s.emailWeeklySummary;
    _productDeals = s.emailProductDeals;
    _proOffers = s.emailProOffers;
  }

  /// Optimistically flips [apply] to [value], persists the single key, and
  /// reverts (with a snackbar) if the PATCH fails.
  void _toggle(String key, bool value, void Function(bool) apply) {
    setState(() => apply(value));
    () async {
      try {
        await ref.read(settingsServiceProvider).updateSettings({key: value});
      } catch (e) {
        if (!mounted) return;
        setState(() => apply(!value));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e is ApiException
                ? e.message
                : "Couldn't save — check your connection."),
          ),
        );
      }
    }();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(settingsProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your preferences.",
                  onRetry: () => ref.invalidate(settingsProvider),
                ),
                data: (s) {
                  _seedOnce(s);
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                  Text(
                    'Control when and how ZOURA reaches you',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _ToggleCard(
                    icon: Icons.notifications_outlined,
                    label: 'Enable Push Notifications',
                    value: _pushEnabled,
                    onChanged: (v) =>
                        _toggle('push_enabled', v, (x) => _pushEnabled = x),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('DAILY REMINDERS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.checkroom_outlined,
                    label: 'Daily Outfit Suggestions',
                    subtitle: '7:00 AM in your timezone (Toronto, EDT)',
                    value: _dailyOutfit,
                    onChanged: (v) => _toggle(
                        'daily_outfit_suggestions', v, (x) => _dailyOutfit = x),
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
                    onChanged: (v) => _toggle(
                        'outfit_reminders', v, (x) => _outfitReminders = x),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('SHOPPING'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Shopping Suggestions',
                    subtitle: 'When ZOURA spots a wardrobe gap',
                    value: _shopping,
                    onChanged: (v) => _toggle(
                        'shopping_suggestions', v, (x) => _shopping = x),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('INSIGHTS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.bar_chart,
                    label: 'Wardrobe Insights',
                    subtitle: 'Weekly summary of closet stats',
                    value: _insights,
                    onChanged: (v) =>
                        _toggle('wardrobe_insights', v, (x) => _insights = x),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel('QUIET HOURS'),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.nightlight_outlined,
                    label: 'Enable Quiet Hours',
                    value: _quietHours,
                    onChanged: (v) => _toggle(
                        'quiet_hours_enabled', v, (x) => _quietHours = x),
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
                    onChanged: (v) => _toggle(
                        'email_weekly_summary', v, (x) => _weeklySummary = x),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.local_offer_outlined,
                    label: 'Product Deals',
                    value: _productDeals,
                    onChanged: (v) => _toggle(
                        'email_product_deals', v, (x) => _productDeals = x),
                  ),
                  const SizedBox(height: 10),
                  _ToggleCard(
                    icon: Icons.star_outline,
                    label: 'Pro Offers',
                    value: _proOffers,
                    onChanged: (v) =>
                        _toggle('email_pro_offers', v, (x) => _proOffers = x),
                  ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
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
