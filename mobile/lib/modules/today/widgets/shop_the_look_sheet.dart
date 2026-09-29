import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../models/outfit.dart';

/// Lists the pieces of an outfit the user doesn't own yet, each with its price
/// and a Buy link. Opened from the card's "Shop the look" button.
class ShopTheLookSheet extends StatelessWidget {
  final Outfit outfit;
  const ShopTheLookSheet({super.key, required this.outfit});

  static Future<void> show(BuildContext context, Outfit outfit) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ivory,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ShopTheLookSheet(outfit: outfit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pieces = outfit.items.where((i) => i.isShopItem).toList();
    final owned = outfit.items.length - pieces.length;
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Shop the look', style: text.titleLarge),
            const SizedBox(height: 4),
            Text(
              owned > 0
                  ? 'Pair ${owned == 1 ? 'your piece' : 'your $owned pieces'} with:'
                  : 'Everything in this look:',
              style: text.bodyMedium?.copyWith(color: AppColors.taupe),
            ),
            const SizedBox(height: 16),
            for (final p in pieces)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 56,
                        height: 56,
                        child: p.primaryImageUrl == null
                            ? const ColoredBox(color: AppColors.ivoryWarm)
                            : CachedNetworkImage(imageUrl: p.primaryImageUrl!, fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: text.titleSmall),
                          Text(
                            [p.retailer, p.priceLabel].whereType<String>().join(' · '),
                            style: text.bodySmall?.copyWith(color: AppColors.taupe),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    BuyPill(onTap: () => openProductLink(context, p.productUrl!)),
                  ],
                ),
              ),
            Text(
              'ZOURA earns a small commission on purchases. Your price is never affected.',
              style: text.bodySmall?.copyWith(color: AppColors.taupe),
            ),
          ],
        ),
      ),
    );
  }
}
