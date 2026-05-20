import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Client-side 2×2 composite of outfit item images.
///
/// Backend decision #2: `outfits.image_url` is null by design; the mobile
/// client composes the visual from up to 4 `primary_image_url` values.
///
/// Cells with no image render a soft icon placeholder so the grid never
/// looks broken when an outfit has < 4 items.
class OutfitItemGrid extends StatelessWidget {
  final List<String?> imageUrls;
  final double aspectRatio;

  const OutfitItemGrid({
    super.key,
    required this.imageUrls,
    this.aspectRatio = 4 / 5,
  });

  @override
  Widget build(BuildContext context) {
    final cells = List<String?>.generate(
      4,
      (i) => i < imageUrls.length ? imageUrls[i] : null,
    );

    return AspectRatio(
      aspectRatio: aspectRatio,
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
            children: cells.map(_OutfitGridCell.new).toList(),
          ),
        ),
      ),
    );
  }
}

class _OutfitGridCell extends StatelessWidget {
  final String? imageUrl;
  const _OutfitGridCell(this.imageUrl);

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: AppColors.white,
        alignment: Alignment.center,
        child: imageUrl == null
            ? const Icon(
                Icons.checkroom_outlined,
                size: 36,
                color: AppColors.taupeSoft,
              )
            : Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.checkroom_outlined,
                  size: 36,
                  color: AppColors.taupeSoft,
                ),
              ),
      ),
    );
  }
}
