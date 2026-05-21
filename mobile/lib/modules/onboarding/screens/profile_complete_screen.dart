import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/session_store.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../today/screens/today_dashboard_screen.dart';

class ProfileCompleteScreen extends StatefulWidget {
  static const path = '/onboarding/profile-complete';
  static const name = 'profile_complete';

  const ProfileCompleteScreen({super.key});

  @override
  State<ProfileCompleteScreen> createState() => _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends State<ProfileCompleteScreen> {
  bool _shareCommunity = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.espressoDeep,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.sage, size: 18),
                const SizedBox(width: 6),
                Text(
                  'Your DRAPE Profile Is Complete',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.sageDim,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Meet your personalized style avatar',
              style: AppTypography.brandMark.copyWith(
                fontSize: 28,
                letterSpacing: 0,
                color: AppColors.brandText,
              ),
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 0.75,
                child: Container(
                  color: AppColors.black,
                  alignment: Alignment.center,
                  child: const Icon(Icons.person,
                      color: AppColors.tan, size: 160),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: const [
                Expanded(child: _StatCard(label: 'MEASUREMENTS', value: '8 of 8', icon: Icons.straighten)),
                SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'WARDROBE', value: '47 items', icon: Icons.checkroom)),
                SizedBox(width: 12),
                Expanded(child: _StatCard(label: 'READY FOR', value: 'AI Outfits', icon: Icons.auto_awesome)),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Your DRAPE avatar is ready — want to share it?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.brandText.withValues(alpha: 0.8),
                    ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            _OutlinedAction(
              icon: Icons.camera_alt_outlined,
              label: 'Share to Instagram Story',
              onPressed: () => debugPrint('share: instagram'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.brandText.withValues(alpha: 0.2)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Share my avatar publicly in DRAPE Community',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandText,
                          ),
                    ),
                  ),
                  Switch(
                    value: _shareCommunity,
                    onChanged: (v) => setState(() => _shareCommunity = v),
                    activeThumbColor: AppColors.sage,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Material(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () async {
                  await SessionStore.setLoggedIn(true);
                  if (context.mounted) {
                    context.goNamed(TodayDashboardScreen.name);
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  child: Text(
                    'See My First Outfit',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppColors.espressoDark,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.gold, size: 20),
          const SizedBox(height: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.6),
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.brandText,
                  fontWeight: FontWeight.w700,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _OutlinedAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.gold, width: 1.5),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          height: 56,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.gold, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.gold,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
