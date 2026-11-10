import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../../../shared/widgets/garment_placeholder.dart';

/// One garment in the collage: its photo (if any) plus the category + colour
/// used to draw a [GarmentPlaceholder] when there's no photo. [buyUrl] is set
/// for pieces the user doesn't own (AWIN products): the tile gets a "Buy" pill.
class GarmentCell {
  final String? imageUrl;
  final String category;
  final Color? color;
  final String? buyUrl;
  const GarmentCell({this.imageUrl, required this.category, this.color, this.buyUrl});
}

/// Fixed-height hero image for an outfit card, composed client-side from the
/// items' photos (backend decision #2: `outfits.image_url` is null by design).
///
/// Layout follows the piece count so it reads like one flat-lay rather than a
/// grid of thumbnails: 1 → full bleed; 2 → side by side; 3 → a tall lead piece
/// plus two stacked; 4 → 2×2; 5+ → a tall lead piece plus a 2×2.
class OutfitCollage extends StatelessWidget {
  final List<GarmentCell> cells;
  final double height;

  const OutfitCollage({super.key, required this.cells, this.height = 260});

  static const _gap = 4.0;

  @override
  Widget build(BuildContext context) {
    final c = cells.take(5).toList();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(color: AppColors.ivoryWarm, child: _layout(c)),
      ),
    );
  }

  Widget _layout(List<GarmentCell> c) {
    // The lead tile sits under the card's top-left dress-level tag, so its
    // Buy pill drops below it.
    Widget tile(GarmentCell cell) =>
        _CollageTile(cell, pillTop: identical(cell, c.first) ? 40 : 8);
    Widget column(List<Widget> children) => Column(
          children: [
            for (final (i, w) in children.indexed) ...[
              if (i > 0) const SizedBox(height: _gap),
              Expanded(child: w),
            ],
          ],
        );
    Widget row(List<Widget> children, {List<int>? flex}) => Row(
          children: [
            for (final (i, w) in children.indexed) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(flex: flex?[i] ?? 1, child: w),
            ],
          ],
        );

    switch (c.length) {
      case 0:
        return const SizedBox.shrink();
      case 1:
        return tile(c[0]);
      case 2:
        return row([tile(c[0]), tile(c[1])]);
      case 3:
        return row([tile(c[0]), column([tile(c[1]), tile(c[2])])], flex: [3, 2]);
      case 4:
        return column([
          row([tile(c[0]), tile(c[1])]),
          row([tile(c[2]), tile(c[3])]),
        ]);
      default:
        return row([
          tile(c[0]),
          column([
            row([tile(c[1]), tile(c[2])]),
            row([tile(c[3]), tile(c[4])]),
          ]),
        ]);
    }
  }
}

class _CollageTile extends StatelessWidget {
  final GarmentCell cell;
  final double pillTop;
  const _CollageTile(this.cell, {this.pillTop = 8});

  @override
  Widget build(BuildContext context) {
    final placeholder =
        GarmentPlaceholder(category: cell.category, color: cell.color);
    final Widget image = cell.imageUrl == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: cell.imageUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorWidget: (_, _, _) => placeholder,
          );
    final url = cell.buyUrl;
    if (url == null) return image;
    void open() => openProductLink(context, url);
    return GestureDetector(
      onTap: open,
      child: Stack(
        fit: StackFit.expand,
        children: [
          image,
          // Top-left of each tile: the card's heart owns the image's top-right
          // corner and its weather badge the bottom-right.
          Positioned(top: pillTop, left: 8, child: BuyPill(onTap: open)),
        ],
      ),
    );
  }
}
