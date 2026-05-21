import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import 'profile_complete_screen.dart';

class AvatarRevealScreen extends StatefulWidget {
  static const path = '/onboarding/avatar-reveal';
  static const name = 'avatar_reveal';

  const AvatarRevealScreen({super.key});

  @override
  State<AvatarRevealScreen> createState() => _AvatarRevealScreenState();
}

class _AvatarRevealScreenState extends State<AvatarRevealScreen> {
  bool _generated = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _generated = true);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Your Avatar'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              const SizedBox(height: 16),
              Text(
                _generated ? 'Meet your avatar' : 'Building your avatar…',
                style: Theme.of(context).textTheme.headlineLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                _generated
                    ? 'Calibrated to your exact measurements. Every outfit DRAPE suggests is rendered on this avatar.'
                    : 'Combining your measurements with style preferences to produce a fit-aware avatar.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: _generated ? const _AvatarPreview() : const _AvatarSkeleton(),
                ),
              ),
              const SizedBox(height: 24),
              DrapeButton(
                label: _generated ? 'See My Profile' : 'Building…',
                onPressed: _generated
                    ? () => context.goNamed(ProfileCompleteScreen.name)
                    : null,
                loading: !_generated,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarSkeleton extends StatelessWidget {
  const _AvatarSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: const Icon(Icons.accessibility_new,
          color: AppColors.taupe, size: 100),
    );
  }
}

class _AvatarPreview extends StatelessWidget {
  const _AvatarPreview();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.espressoDeep, AppColors.espressoDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.accessibility_new,
              color: AppColors.tan, size: 140),
          const SizedBox(height: 16),
          Text(
            'AVATAR READY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.gold,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
