import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../onboarding_controller.dart';
import 'avatar_reveal_screen.dart';

/// Onboarding wardrobe step. Four forward paths:
///   * Upload Photos → onboarding-scoped batch upload (AI detect → bulk add)
///   * Scan New Item → onboarding-scoped single scan
///   * Add manually instead → onboarding-scoped manual entry
///   * Start with a starter wardrobe → curated set, auto-deactivates as the
///     user adds real items
/// The first three reuse the Wardrobe-module screens via onboarding-scoped
/// routes so they pop back here instead of leaking into the main tab shell.
class WardrobeSetupScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/wardrobe-setup';
  static const name = 'wardrobe_setup';

  const WardrobeSetupScreen({super.key});

  @override
  ConsumerState<WardrobeSetupScreen> createState() =>
      _WardrobeSetupScreenState();
}

class _WardrobeSetupScreenState extends ConsumerState<WardrobeSetupScreen> {
  bool _assigning = false;

  Future<void> _useStarterWardrobe() async {
    if (_assigning) return;
    setState(() => _assigning = true);
    try {
      final result = await ref
          .read(onboardingControllerProvider.notifier)
          .assignStarterWardrobe();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${result.displayCount} starter pieces to your wardrobe.',
          ),
        ),
      );
      context.pushNamed(AvatarRevealScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _assigning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Real (non-starter) item count gates the "Continue with my items" CTA and
    // drives the live "X of 10" hint. Sub-screens invalidate this provider
    // after each create, so pushNamed→pop refreshes the count.
    final capacity = ref.watch(wardrobeCapacityProvider);
    final addedCount = capacity.maybeWhen(
      data: (c) => c.used,
      orElse: () => 0,
    );
    return Scaffold(
      appBar: DrapeAppBar(
        title: 'Build Your Wardrobe',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'STEP 1 OF 2',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.espressoDark,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 180,
                color: AppColors.ivoryWarm,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(Icons.checkroom,
                        size: 100, color: AppColors.taupe),
                    Positioned(
                      bottom: 16,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.white,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.checkroom,
                            color: AppColors.espresso, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              addedCount >= 10
                  ? "You're set — $addedCount items added."
                  : 'Added $addedCount of 10 — get your first outfit at 10.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'More items = better suggestions.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 24),
            _ActionCard(
              icon: Icons.photo_library_outlined,
              title: 'Upload Photos',
              body: 'Add multiple items at once from your camera roll',
              onTap: _assigning
                  ? null
                  : () =>
                      context.pushNamed('onboarding_wardrobe_batch_upload'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.qr_code_scanner_outlined,
              title: 'Scan New Item',
              body: "Point at any garment for instant auto-tagging",
              onTap: _assigning
                  ? null
                  : () => context.pushNamed('onboarding_wardrobe_scan'),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: _assigning
                    ? null
                    : () =>
                        context.pushNamed('onboarding_wardrobe_manual_entry'),
                child: Text(
                  'Add manually instead',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.inkSoft,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
            if (addedCount >= 1) ...[
              const SizedBox(height: 16),
              Center(
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 14),
                  ),
                  onPressed: _assigning
                      ? null
                      : () => context.pushNamed(AvatarRevealScreen.name),
                  child: Text(
                    'CONTINUE WITH MY ITEMS',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.white,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: _assigning ? null : _useStarterWardrobe,
                child: _assigning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        'START WITH A STARTER WARDROBE',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.espresso,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
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

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;
  const _ActionCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(body, style: Theme.of(context).textTheme.bodySmall),
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
