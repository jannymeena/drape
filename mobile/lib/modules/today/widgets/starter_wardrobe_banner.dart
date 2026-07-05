import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Starter-wardrobe transition banner — mirrors the
/// `atelier_starter_wardrobe_indicator` mockup. Shown on Today (backend
/// `banners.starter_wardrobe`, dismissible for 7 days) and on the Wardrobe
/// grid (with [realItems]/[goalItems] progress toward real-wardrobe mode).
class StarterWardrobeBanner extends StatelessWidget {
  final int? realItems;
  final int goalItems;
  final VoidCallback onAdd;
  final VoidCallback? onDismiss;

  const StarterWardrobeBanner({
    super.key,
    this.realItems,
    this.goalItems = 10,
    required this.onAdd,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.goldSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.palette_outlined,
                  color: Color(0xFFC8901C), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "You're seeing outfits from a starter wardrobe. Add your "
                  'real items for personalized suggestions.',
                  style: textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          if (realItems != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goalItems == 0
                    ? 0
                    : (realItems! / goalItems).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.sand,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFC8901C)),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$realItems/$goalItems ITEMS TO UNLOCK REAL WARDROBE MODE',
              style: textTheme.labelSmall?.copyWith(
                color: const Color(0xFFC8901C),
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Material(
                color: AppColors.espresso,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onAdd,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    child: Text(
                      'Add Your First Item',
                      style: textTheme.labelLarge?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              if (onDismiss != null) ...[
                const SizedBox(width: 12),
                TextButton(
                  onPressed: onDismiss,
                  child: Text(
                    "I'll do this later",
                    style: textTheme.labelLarge?.copyWith(
                      color: AppColors.inkSoft,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
