import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../auth/auth_controller.dart';
import '../../profile/profile_service.dart';
import '../../wardrobe/image_pick.dart';
import '../onboarding_controller.dart';
import 'profile_complete_screen.dart';

/// Avatar step. The avatar is the user's own photo (uploaded via
/// `POST /profile/avatar/upload`) — ZOURA renders outfit suggestions against it.
/// Tap to add a photo now, or skip and add it later from the profile.
class AvatarRevealScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/avatar-reveal';
  static const name = 'avatar_reveal';

  const AvatarRevealScreen({super.key});

  @override
  ConsumerState<AvatarRevealScreen> createState() => _AvatarRevealScreenState();
}

class _AvatarRevealScreenState extends ConsumerState<AvatarRevealScreen> {
  bool _uploading = false;

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

  /// Records the avatar step before moving on so a later relaunch resumes to
  /// Today rather than back here.
  Future<void> _onContinue() async {
    try {
      await ref
          .read(onboardingControllerProvider.notifier)
          .saveProgress('avatar_reveal');
    } on ApiException {
      // Best-effort: don't block finishing onboarding on a failed save.
    }
    if (mounted) context.pushNamed(ProfileCompleteScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = ref.watch(currentUserProvider).valueOrNull?.avatarUrl;
    final hasAvatar = avatarUrl != null && avatarUrl.isNotEmpty;

    return Scaffold(
      appBar: const DrapeAppBar(title: 'Your Avatar'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                hasAvatar ? 'Looking good' : 'Create your style avatar',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                hasAvatar
                    ? 'ZOURA renders every outfit suggestion against your photo. Tap to change it.'
                    : 'Add a photo so ZOURA can show outfits on you. You can change or add this anytime.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: GestureDetector(
                  onTap: _uploading ? null : _pickAvatar,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (hasAvatar)
                          Image.network(
                            avatarUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const _AvatarEmpty(),
                          )
                        else
                          const _AvatarEmpty(),
                        if (_uploading)
                          Container(
                            color: AppColors.black.withValues(alpha: 0.4),
                            alignment: Alignment.center,
                            child: const CircularProgressIndicator(
                                color: AppColors.gold),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              DrapeButton(
                label: hasAvatar ? 'See My Profile' : 'Add a Photo',
                onPressed: _uploading
                    ? null
                    : (hasAvatar ? _onContinue : _pickAvatar),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _uploading ? null : _onContinue,
                child: Text(
                  hasAvatar ? 'Continue' : 'Skip for now',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.taupe,
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
      color: AppColors.ivoryWarm,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.add_a_photo_outlined,
              color: AppColors.taupe, size: 72),
          const SizedBox(height: 12),
          Text(
            'Tap to add your photo',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.taupe,
                ),
          ),
        ],
      ),
    );
  }
}
