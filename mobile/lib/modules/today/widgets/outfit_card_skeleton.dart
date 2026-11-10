import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import 'outfit_card.dart';

const _cardDecoration = BoxDecoration(
  color: AppColors.white,
  borderRadius: BorderRadius.all(Radius.circular(20)),
  boxShadow: todayCardShadow,
);

const _r8 = BorderRadius.all(Radius.circular(8));

/// Placeholder shown while an occasion's outfit is being generated. Mirrors
/// [OutfitCard]'s shell (same container, 260dp hero, title/reason/chip rows,
/// CTA + action row) so the swap to the real card is seamless.
class OutfitCardSkeleton extends StatelessWidget {
  const OutfitCardSkeleton({super.key, this.occasionLabel});

  /// Occasion this skeleton is styling (e.g. "Work"), shown as a small badge so
  /// the user knows what's coming.
  final String? occasionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              const ShimmerSkeleton(
                height: 260,
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              if (occasionLabel != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.ivory.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'STYLING ${occasionLabel!.toUpperCase()}…',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.ink,
                            fontSize: 11,
                            letterSpacing: 1.1,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 180, child: ShimmerSkeleton(height: 26, borderRadius: _r8)),
                SizedBox(height: 6),
                SizedBox(width: 150, child: ShimmerSkeleton(height: 14)),
                SizedBox(height: 12),
                ShimmerSkeleton(height: 40, borderRadius: _r8),
                SizedBox(height: 12),
                SizedBox(width: 220, child: ShimmerSkeleton(height: 22, borderRadius: BorderRadius.all(Radius.circular(999)))),
                SizedBox(height: 12),
                ShimmerSkeleton(height: 48, borderRadius: BorderRadius.all(Radius.circular(12))),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: ShimmerSkeleton(height: 36, borderRadius: _r8)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerSkeleton(height: 36, borderRadius: _r8)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerSkeleton(height: 36, borderRadius: _r8)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Card-shaped error slot shown when one occasion's generation failed. Keeps the
/// carousel stable and offers a scoped retry — the rest of the dashboard is
/// unaffected.
class OutfitOccasionRetryCard extends StatelessWidget {
  const OutfitOccasionRetryCard({
    super.key,
    required this.occasionLabel,
    required this.message,
    required this.onRetry,
  });

  final String occasionLabel;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.refresh_rounded, color: AppColors.taupe, size: 36),
          const SizedBox(height: 12),
          Text(
            "Couldn't style your $occasionLabel look",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.espressoDeep,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}
