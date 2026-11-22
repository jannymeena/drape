import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import 'wardrobe_picture.dart';

class WardrobeItemData {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;

  /// [imageUrl] is a mannequin shot: laid whole on [backgroundAsset].
  /// Otherwise it's the user's photo, shown as it is.
  final bool mannequinShot;

  /// The mannequin shot is still being made: a loading indicator over the
  /// photo.
  final bool processing;
  final String? backgroundAsset;
  final String? colorHex;
  final bool favorited;
  final bool starter;

  const WardrobeItemData({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
    this.mannequinShot = false,
    this.processing = false,
    this.backgroundAsset,
    this.colorHex,
    this.favorited = false,
    this.starter = false,
  });
}

class ItemCard extends StatelessWidget {
  final WardrobeItemData item;
  final VoidCallback? onTap;
  final VoidCallback? onFavorite;

  const ItemCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavorite,
  });

  static const _shotPadding = EdgeInsets.all(12);

  Widget _placeholder() => GarmentPlaceholder(
        category: item.category,
        color: garmentColorFromHex(item.colorHex),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: WardrobePicture(
                        imageUrl: item.imageUrl,
                        placeholder: _placeholder(),
                        mannequinShot: item.mannequinShot,
                        processing: item.processing,
                        backgroundAsset: item.backgroundAsset,
                        // The whole shot, clear of the card's edges (and the
                        // star badge).
                        shotPadding: _shotPadding,
                      ),
                    ),
                  ),
                  if (item.starter)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.tanFixed,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'STARTER',
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.espressoDark,
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
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.85),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item.favorited ? Icons.star : Icons.star_border,
                          color: item.favorited
                              ? AppColors.gold
                              : AppColors.espresso,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.category.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.taupe,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
