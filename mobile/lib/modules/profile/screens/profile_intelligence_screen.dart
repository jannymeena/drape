import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';

class ProfileIntelligenceScreen extends StatelessWidget {
  static const path = '/profile';
  static const name = 'profile_intelligence';

  const ProfileIntelligenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TopBar(onSettings: () => context.goNamed(SettingsScreen.name))),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _ProfileHeader(onEdit: () => context.goNamed(EditProfileScreen.name)),
                  const SizedBox(height: 24),
                  Text(
                    'WARDROBE INTELLIGENCE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const _StatGrid(),
                  const SizedBox(height: 16),
                  const _AvatarCard(),
                  const SizedBox(height: 12),
                  const _WardrobeWrappedCard(),
                  const SizedBox(height: 16),
                  const _InviteFriendsCard(),
                  const SizedBox(height: 16),
                  _SettingsEntryCard(onTap: () => context.goNamed(SettingsScreen.name)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onSettings;
  const _TopBar({required this.onSettings});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: AppColors.espresso),
            onPressed: () => debugPrint('profile: menu'),
          ),
          Expanded(
            child: Text(
              'Atelier Profile',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.espresso),
            onPressed: onSettings,
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final VoidCallback onEdit;
  const _ProfileHeader({required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: AppColors.espresso,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            'AC',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Alex Ch…',
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.gold,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'DRAPE PRO',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.espressoDark,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Pro Member ✦',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                'Member since March 2025',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        OutlinedButton(
          onPressed: onEdit,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.espresso,
            side: const BorderSide(color: AppColors.taupeSoft),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
          child: Text(
            'Edit Profile',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: const [
        _StatCard(
          value: '34%',
          label: 'Utilization Score',
          trend: _Trend.up,
        ),
        _StatCard(
          value: r'$4.20',
          label: 'Avg Cost/Wear',
          trend: _Trend.down,
        ),
        _StatCard(
          value: '23',
          label: 'items unworn 60d+',
          trend: _Trend.warning,
          accent: AppColors.gold,
        ),
        _StatCard(
          value: r'$4,200',
          label: 'Wardrobe Value',
        ),
      ],
    );
  }
}

enum _Trend { up, down, warning, none }

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final _Trend trend;
  final Color? accent;

  const _StatCard({
    required this.value,
    required this.label,
    this.trend = _Trend.none,
    this.accent,
  });

  IconData? get _icon => switch (trend) {
        _Trend.up => Icons.trending_up,
        _Trend.down => Icons.trending_down,
        _Trend.warning => Icons.warning_amber_rounded,
        _Trend.none => null,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: accent ?? AppColors.espressoDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              if (_icon != null)
                Icon(_icon, color: AppColors.taupe, size: 16),
            ],
          ),
          const Spacer(),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _AvatarCard extends StatelessWidget {
  const _AvatarCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: AppColors.espresso, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Avatar',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: const [
                    _AvatarChip(label: "5'11\""),
                    _AvatarChip(label: '38" chest'),
                    _AvatarChip(label: '32" waist'),
                  ],
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => debugPrint('profile: update measurements'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.taupeSoft),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Update Measurements',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward, size: 12, color: AppColors.espresso),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AvatarChip extends StatelessWidget {
  final String label;
  const _AvatarChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.inkSoft,
            ),
      ),
    );
  }
}

class _WardrobeWrappedCard extends StatelessWidget {
  const _WardrobeWrappedCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        color: AppColors.gold, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'Wardrobe Wrapped',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.brandText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Your year in style · Available December 2026.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.brandText.withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock Pro →',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.gold,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.gold,
                      ),
                ),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_outline,
                color: AppColors.brandText, size: 18),
          ),
        ],
      ),
    );
  }
}

class _InviteFriendsCard extends StatelessWidget {
  const _InviteFriendsCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Invite Friends, Earn Pro',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '8 / 20 activations',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '1 free month',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.gold,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 8 / 20,
              minHeight: 4,
              backgroundColor: AppColors.tanFixed,
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.tanFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'drape.app/r/alex2024',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.espressoDark,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const Icon(Icons.copy, color: AppColors.espresso, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsEntryCard extends StatelessWidget {
  final VoidCallback onTap;
  const _SettingsEntryCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryWarm,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.settings_outlined,
                    color: AppColors.espresso, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Settings',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      'Notifications, appearance, privacy, account',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}
