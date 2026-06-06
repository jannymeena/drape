import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';

const _cardDecoration = BoxDecoration(
  color: Color(0xFFFDF2E8),
  borderRadius: BorderRadius.all(Radius.circular(24)),
  boxShadow: [
    BoxShadow(color: Color(0x0F2A1810), blurRadius: 48, offset: Offset(0, 24)),
  ],
);

/// Placeholder shown while an occasion's outfit is being generated. Mirrors
/// [OutfitCard]'s shell (same container, 2×2 grid, reasoning + action rows) so
/// the swap to the real card is seamless.
class OutfitCardSkeleton extends StatelessWidget {
  const OutfitCardSkeleton({super.key, this.occasionLabel});

  /// Occasion this skeleton is styling (e.g. "Work"), shown as a small badge so
  /// the user knows what's coming.
  final String? occasionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              AspectRatio(
                aspectRatio: 4 / 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    color: AppColors.ivoryWarm,
                    padding: const EdgeInsets.all(6),
                    child: GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 6,
                      mainAxisSpacing: 6,
                      physics: const NeverScrollableScrollPhysics(),
                      children: List.generate(
                        4,
                        (_) => const ShimmerSkeleton(
                          borderRadius:
                              BorderRadius.all(Radius.circular(8)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (occasionLabel != null)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.tanFixed,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'STYLING ${occasionLabel!.toUpperCase()}…',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.espresso,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          const ShimmerSkeleton(
            height: 80,
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Expanded(
                child: ShimmerSkeleton(
                    height: 44,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ShimmerSkeleton(
                    height: 44,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
              SizedBox(width: 8),
              Expanded(
                child: ShimmerSkeleton(
                    height: 44,
                    borderRadius: BorderRadius.all(Radius.circular(12))),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Card-shaped error slot shown when one occasion's generation failed. Keeps the
/// list layout stable and offers a scoped retry — the rest of the dashboard is
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
        mainAxisSize: MainAxisSize.min,
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
