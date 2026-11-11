import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import 'outfit_card.dart';

/// One product tile in Today's "Shop the look" row.
class ShopPick {
  final String name;
  final String? imageUrl;
  final String category;

  /// e.g. "$149 CAD".
  final String priceText;
  final String url;

  const ShopPick({
    required this.name,
    required this.imageUrl,
    required this.category,
    required this.priceText,
    required this.url,
  });

  /// "$149 CAD" / "$24.50 USD" — whole amounts drop the cents.
  static String formatPrice(int cents, String currency) {
    final amount = cents % 100 == 0
        ? '${cents ~/ 100}'
        : (cents / 100).toStringAsFixed(2);
    return '\$$amount $currency';
  }
}

/// The wardrobe-gap card under the product row ("Fills a gap: …").
class GapPick {
  final String title;
  final String body;
  const GapPick({required this.title, required this.body});
}

/// "Shop the look": up to three affiliate picks and a wardrobe-gap card.
/// Hidden by the caller when there's nothing to show.
class TodayShopSection extends StatelessWidget {
  final List<ShopPick> picks;
  final GapPick? gap;
  final ValueChanged<ShopPick> onPickTap;
  final VoidCallback? onViewGap;

  const TodayShopSection({
    super.key,
    required this.picks,
    required this.onPickTap,
    this.gap,
    this.onViewGap,
  });

  @override
  Widget build(BuildContext context) {
    final shown = picks.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Shop the look',
          style: AppTypography.sectionTitle,
        ),
        if (shown.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: i < shown.length
                      ? _PickTile(pick: shown[i], onTap: () => onPickTap(shown[i]))
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
        if (gap != null) ...[
          const SizedBox(height: 12),
          _GapCard(gap: gap!, onView: onViewGap),
        ],
      ],
    );
  }
}

class _PickTile extends StatelessWidget {
  final ShopPick pick;
  final VoidCallback onTap;
  const _PickTile({required this.pick, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final placeholder = GarmentPlaceholder(category: pick.category);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: todayCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(
                        color: AppColors.ivoryWarm,
                        child: pick.imageUrl == null || pick.imageUrl!.isEmpty
                            ? placeholder
                            : CachedNetworkImage(
                                imageUrl: pick.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, _, _) => placeholder,
                              ),
                      ),
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.ivory.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            pick.priceText,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: AppColors.ink,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pick.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.ink,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GapCard extends StatelessWidget {
  final GapPick gap;
  final VoidCallback? onView;
  const _GapCard({required this.gap, this.onView});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            gap.title,
            style: text.headlineSmall?.copyWith(
              fontSize: 20,
              color: AppColors.espressoDark,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(gap.body, style: text.bodySmall?.copyWith(height: 1.5)),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: FilledButton(
              onPressed: onView,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.espresso,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: text.labelMedium,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('See what fills it'),
                  SizedBox(width: 6),
                  Icon(Icons.arrow_forward, size: 15),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
