import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class ProductData {
  final String id;
  final String brand;
  final String name;
  final String price;
  final String? imageUrl;
  final bool onSale;
  final String? oldPrice;
  final int? unlockCount;

  const ProductData({
    required this.id,
    required this.brand,
    required this.name,
    required this.price,
    this.imageUrl,
    this.onSale = false,
    this.oldPrice,
    this.unlockCount,
  });
}

/// Shop product tile: image (heart toggle + optional unlock/sale badge), brand,
/// name, price. Used in the shop feed and gap-analysis grids.
class ProductCard extends StatelessWidget {
  final ProductData product;
  final bool favorited;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;
  final bool showViewOptions;
  final VoidCallback? onViewOptions;

  const ProductCard({
    super.key,
    required this.product,
    this.favorited = false,
    this.onTap,
    this.onFavorite,
    this.showViewOptions = false,
    this.onViewOptions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: AppColors.ivoryWarm,
                      child: product.imageUrl == null
                          ? const Center(
                              child: Icon(Icons.checkroom_outlined,
                                  color: AppColors.taupeSoft, size: 40),
                            )
                          : Image.network(
                              product.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.checkroom_outlined,
                                    color: AppColors.taupeSoft),
                              ),
                            ),
                    ),
                  ),
                ),
                if (product.unlockCount != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.sage,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock_open,
                              color: AppColors.white, size: 11),
                          const SizedBox(width: 3),
                          Text(
                            'Unlock ${product.unlockCount}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (product.onSale)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'SALE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onFavorite,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.white.withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        favorited ? Icons.favorite : Icons.favorite_border,
                        color: favorited ? AppColors.gold : AppColors.espresso,
                        size: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.brand.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              if (product.oldPrice != null) ...[
                Text(
                  product.oldPrice!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.taupe,
                        decoration: TextDecoration.lineThrough,
                      ),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                product.price,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: product.onSale ? AppColors.error : AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (showViewOptions) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: Material(
                color: AppColors.espresso,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onViewOptions,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                      child: Text(
                        'VIEW OPTIONS',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.white,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
