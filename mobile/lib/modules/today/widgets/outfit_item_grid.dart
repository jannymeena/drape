import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/garment_placeholder.dart';

/// One garment in the grid: its photo (if any) plus the category + colour used
/// to draw a [GarmentPlaceholder] when there's no photo (e.g. starter items).
class GarmentCell {
  final String? imageUrl;
  final String category;
  final Color? color;
  const GarmentCell({this.imageUrl, required this.category, this.color});
}

/// Client-side 2×2 composite of outfit item images.
///
/// Backend decision #2: `outfits.image_url` is null by design; the mobile
/// client composes the visual from up to 4 items. Items without a photo render
/// a coloured category silhouette; unused slots render a blank tile.
class OutfitItemGrid extends StatelessWidget {
  final List<GarmentCell> cells;
  final double aspectRatio;

  const OutfitItemGrid({
    super.key,
    required this.cells,
    this.aspectRatio = 4 / 5,
  });

  @override
  Widget build(BuildContext context) {
    final padded = List<GarmentCell?>.generate(
      4,
      (i) => i < cells.length ? cells[i] : null,
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
            children: padded.map((c) => _OutfitGridCell(c)).toList(),
          ),
        ),
      ),
    );
  }
}

class _OutfitGridCell extends StatelessWidget {
  final GarmentCell? cell;
  const _OutfitGridCell(this.cell);

  @override
  Widget build(BuildContext context) {
    final cell = this.cell;
    final Widget child;
    if (cell == null) {
      child = const ColoredBox(color: AppColors.white); // empty slot
    } else if (cell.imageUrl == null) {
      child = GarmentPlaceholder(category: cell.category, color: cell.color);
    } else {
      child = Image.network(
        cell.imageUrl!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) =>
            GarmentPlaceholder(category: cell.category, color: cell.color),
      );
    }
    return ClipRRect(borderRadius: BorderRadius.circular(8), child: child);
  }
}
