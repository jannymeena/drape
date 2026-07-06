import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// Designed empty state for a truly empty wardrobe (All Pieces, 0 items) —
/// mirrors `screens/CTO_Handoff_Wardrobe_Tab/wardrobe_empty_state`.
class WardrobeEmptyState extends StatelessWidget {
  final VoidCallback onAdd;

  const WardrobeEmptyState({super.key, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 40, 32, 24),
      child: Column(
        children: [
          const _IconCircle(icon: Icons.checkroom_outlined),
          const SizedBox(height: 28),
          Text(
            'Your digital wardrobe awaits',
            textAlign: TextAlign.center,
            style: textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Add at least 10 items to unlock personalized AI outfit '
            'suggestions based on what you actually own.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          const _Benefit('AI outfits from your real wardrobe'),
          const _Benefit('Cost-per-wear tracking'),
          const _Benefit('Never forget what you own'),
          const SizedBox(height: 28),
          DrapeButton(
            label: '+ Add Your First Item',
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

/// Designed empty state for the Favorites filter with no favorited items —
/// mirrors `screens/CTO_Handoff_Wardrobe_Tab/favorites_empty_state`:
/// star circle + copy, with the "Style inspiration" card linking to the
/// Shop feed (the mockup's Atelier collection) at the bottom.
class FavoritesEmptyState extends StatelessWidget {
  final VoidCallback onExplore;

  const FavoritesEmptyState({super.key, required this.onExplore});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
      child: Column(
        children: [
          const _IconCircle(icon: Icons.star),
          const SizedBox(height: 28),
          Text(
            'No favorites yet',
            textAlign: TextAlign.center,
            style: textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the star on any item to save it here for quick access.',
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 44),
          _StyleInspirationCard(onTap: onExplore),
        ],
      ),
    );
  }
}

/// Editorial cross-sell card from the `favorites_empty_state` mockup: sage
/// "STYLE INSPIRATION" badge overlapping an image card that opens the Shop
/// feed. Reuses the bundled onboarding flat-lay as the editorial image.
class _StyleInspirationCard extends StatelessWidget {
  final VoidCallback onTap;
  const _StyleInspirationCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: AppColors.ivoryWarm,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.asset(
                  'assets/onboarding/welcome_flat_lay.png',
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discover new essentials',
                        style: textTheme.headlineSmall?.copyWith(
                          fontSize: 20,
                          fontStyle: FontStyle.italic,
                          color: AppColors.espressoDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'EXPLORE THE ATELIER COLLECTION',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 2,
                          color: AppColors.taupe,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: -10,
          left: -6,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sage,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'STYLE INSPIRATION',
              style: textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: AppColors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  final IconData icon;
  const _IconCircle({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: const BoxDecoration(
        color: AppColors.ivoryDim,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 48, color: AppColors.taupeSoft),
    );
  }
}

class _Benefit extends StatelessWidget {
  final String text;
  const _Benefit(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 20, color: AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
