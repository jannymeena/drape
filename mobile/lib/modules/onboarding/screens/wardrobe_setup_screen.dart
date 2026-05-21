import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import 'avatar_reveal_screen.dart';

class WardrobeSetupScreen extends StatelessWidget {
  static const path = '/onboarding/wardrobe-setup';
  static const name = 'wardrobe_setup';

  const WardrobeSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              'Add at least 10 items to get your first outfit.',
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
              onTap: () => debugPrint('wardrobe: upload'),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              icon: Icons.qr_code_scanner_outlined,
              title: 'Scan New Item',
              body: "Point at any garment for instant auto-tagging",
              onTap: () => debugPrint('wardrobe: scan'),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => debugPrint('wardrobe: manual'),
                child: Text(
                  'Add manually instead',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.inkSoft,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
            Center(
              child: TextButton(
                onPressed: () => context.goNamed(AvatarRevealScreen.name),
                child: Text(
                  'SKIP FOR NOW',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.inkSoft,
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
  final VoidCallback onTap;
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
