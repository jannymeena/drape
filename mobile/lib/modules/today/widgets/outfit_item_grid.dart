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

/// Client-side composite of an outfit's item images (2 columns, square tiles).
///
/// Backend decision #2: `outfits.image_url` is null by design; the mobile
/// client composes the visual from up to 4 items. The grid **shrink-wraps** to
/// the number of items, so the card height follows the content: a 2-item outfit
/// is one short row, a 3–4 item outfit is two rows. No blank padding tiles.
/// Items without a photo render a coloured category silhouette.
class OutfitItemGrid extends StatelessWidget {
  final List<GarmentCell> cells;

  const OutfitItemGrid({super.key, required this.cells});

  @override
  Widget build(BuildContext context) {
    final items = cells.take(4).toList();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: AppColors.ivoryWarm,
        padding: const EdgeInsets.all(6),
        child: GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 6,
          mainAxisSpacing: 6,
          childAspectRatio: 1, // square tiles; height grows by the row
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [for (final c in items) _OutfitGridCell(c)],
        ),
      ),
    );
  }
}

class _OutfitGridCell extends StatelessWidget {
  final GarmentCell cell;
  const _OutfitGridCell(this.cell);

  @override
  Widget build(BuildContext context) {
    final Widget child;
    if (cell.imageUrl == null) {
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
