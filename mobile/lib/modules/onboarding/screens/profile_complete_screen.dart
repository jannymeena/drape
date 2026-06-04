import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/services/session_store.dart';
import '../../../shared/services/share_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../auth/auth_controller.dart';
import '../../profile/profile_service.dart';
import '../../today/screens/today_dashboard_screen.dart';
import '../../wardrobe/image_pick.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../onboarding_controller.dart';

/// Total wardrobe items (starter + added) for the "WARDROBE" stat.
final _wardrobeCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final res = await ref.read(wardrobeServiceProvider).getItems(limit: 1);
  return res.total;
});

class ProfileCompleteScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/profile-complete';
  static const name = 'profile_complete';

  const ProfileCompleteScreen({super.key});

  @override
  ConsumerState<ProfileCompleteScreen> createState() =>
      _ProfileCompleteScreenState();
}

class _ProfileCompleteScreenState extends ConsumerState<ProfileCompleteScreen> {
  /// Null until the user's stored value loads; then mirrors it locally.
  bool? _shareCommunity;
  bool _uploading = false;

  /// Persist the community-share opt-in. Optimistic: flips locally, then PATCHes
  /// `community_share_avatar`; reverts on failure.
  Future<void> _setShareCommunity(bool value) async {
    final user = ref.read(currentUserProvider).valueOrNull;
    if (user == null) return;
    setState(() => _shareCommunity = value);
    try {
      final updated = await ref.read(profileServiceProvider).updateProfile(
            userId: user.id,
            communityShareAvatar: value,
          );
      ref.read(authControllerProvider.notifier).applyCurrentUser(updated);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _shareCommunity = !value);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  /// Pick a photo and store it as the avatar. The refreshed user (carrying the
  /// new `avatarUrl`) is pushed into [AuthController] so this screen — and the
  /// Profile tab — re-render with the real image.
  Future<void> _pickAvatar() async {
    final picked = await pickWardrobeImage(context);
    if (picked == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final updated =
          await ref.read(profileServiceProvider).uploadAvatar(picked);
      ref.read(authControllerProvider.notifier).applyCurrentUser(updated);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    final avatarUrl = user?.avatarUrl;
    final shareCommunity = _shareCommunity ?? user?.communityShareAvatar ?? false;
    final measured =
        ref.watch(onboardingControllerProvider).measurements.values.length;
    final wardrobeCount = ref.watch(_wardrobeCountProvider).valueOrNull ?? 0;

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
            _AvatarCard(
              avatarUrl: avatarUrl,
              uploading: _uploading,
              onTap: _uploading ? null : _pickAvatar,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'MEASUREMENTS',
                    value: '$measured of 8',
                    icon: Icons.straighten,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    label: 'WARDROBE',
                    value: '$wardrobeCount ${wardrobeCount == 1 ? 'item' : 'items'}',
                    icon: Icons.checkroom,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: _StatCard(
                    label: 'READY FOR',
                    value: 'AI Outfits',
                    icon: Icons.auto_awesome,
                  ),
                ),
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
              onPressed: () => shareText(
                'Just built my AI-styled wardrobe with DRAPE 👗✨',
                subject: 'My DRAPE wardrobe',
              ),
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
                    value: shareCommunity,
                    onChanged: _setShareCommunity,
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

class _AvatarCard extends StatelessWidget {
  final String? avatarUrl;
  final bool uploading;
  final VoidCallback? onTap;
  const _AvatarCard({
    required this.avatarUrl,
    required this.uploading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 0.75,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasAvatar)
                Image.network(
                  avatarUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const _AvatarEmpty(),
                )
              else
                const _AvatarEmpty(),
              if (uploading)
                Container(
                  color: AppColors.black.withValues(alpha: 0.5),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(color: AppColors.gold),
                ),
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined,
                          color: AppColors.gold, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        hasAvatar ? 'Change photo' : 'Add your photo',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.brandText,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarEmpty extends StatelessWidget {
  const _AvatarEmpty();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.black,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_a_photo_outlined,
              color: AppColors.tan, size: 72),
          const SizedBox(height: 12),
          Text(
            'Tap to add your photo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.8),
                ),
          ),
        ],
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
