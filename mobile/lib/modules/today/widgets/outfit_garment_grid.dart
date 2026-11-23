import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import 'outfit_collage.dart';

/// An outfit's picture as its garments' own photos in a grid — for looks
/// the flat-lay can't compose: starter-wardrobe looks (shop photos) and
/// looks whose pieces aren't all cut out yet.
///
/// The lead piece (highest dress priority — the coat, the dress, the top)
/// is a tall tile on the left with its name; the rest stack on the right,
/// up to three, the last one counting any more ("+2"). Shop pieces open
/// their product page and carry a Buy pill.
class OutfitGarmentGrid extends StatelessWidget {
  final List<GarmentCell> cells;
  final double height;

  /// Most tiles in the right column.
  static const maxSide = 3;
  static const _gap = 8.0;

  const OutfitGarmentGrid({super.key, required this.cells, this.height = 260});

  /// Whether a look shows as this grid rather than the flat-lay: any piece
  /// to shop, or not yet cut out.
  static bool suits(List<GarmentCell> cells) =>
      cells.any((c) => c.buyUrl != null || !c.hasCutout);

  @override
  Widget build(BuildContext context) {
    if (cells.isEmpty) return SizedBox(height: height);
    final ordered = [...cells]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    final hero = ordered.first;
    final rest = ordered.skip(1).toList();
    final side = rest.take(maxSide).toList();
    final more = rest.length - side.length;
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: rest.isEmpty ? 1 : 3,
            child: _Tile(hero, lead: true),
          ),
          if (side.isNotEmpty) ...[
            const SizedBox(width: _gap),
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, cell) in side.indexed) ...[
                    if (i > 0) const SizedBox(height: _gap),
                    Expanded(
                      child: _Tile(
                        cell,
                        more: i == side.length - 1 ? more : 0,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final GarmentCell cell;

  /// The tall left tile: the photo fills it, with the piece's name.
  final bool lead;

  /// Pieces past the grid, counted on this tile ("+2").
  final int more;

  const _Tile(this.cell, {this.lead = false, this.more = 0});

  @override
  Widget build(BuildContext context) {
    // A photo that doesn't load shows as broken; a shop piece is only ever
    // its own photo, and only an own piece with no photo gets the drawing.
    final Widget placeholder = cell.buyUrl != null
        ? const BrokenImageTile()
        : Padding(
            padding: const EdgeInsets.all(16),
            child: GarmentPlaceholder(category: cell.category, color: cell.color),
          );
    final url = cell.imageUrl;
    final photo = url == null
        ? placeholder
        : CachedNetworkImage(
            imageUrl: url,
            // The lead fills its tile; the small ones show the whole piece.
            fit: lead ? BoxFit.cover : BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
            fadeInDuration: const Duration(milliseconds: 150),
            errorWidget: (_, _, _) => const BrokenImageTile(),
          );
    final buyUrl = cell.buyUrl;
    final name = cell.name;
    final text = Theme.of(context).textTheme;
    Widget tile = ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ColoredBox(
        color: AppColors.ivoryWarm,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: lead ? EdgeInsets.zero : const EdgeInsets.all(8),
              child: photo,
            ),
            if (lead && name != null && name.isNotEmpty)
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.88),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: Text(
                        name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelSmall?.copyWith(
                          color: AppColors.ink,
                          fontSize: 11,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (more > 0)
              ColoredBox(
                color: AppColors.espressoDeep.withValues(alpha: 0.45),
                child: Center(
                  child: Text(
                    '+$more',
                    style: text.titleMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            if (buyUrl != null && more == 0)
              Positioned(
                top: 8,
                // Clear of the card's corner pills (dress level top-left of
                // the lead, heart top-right of the column).
                left: lead ? null : 8,
                right: lead ? 8 : null,
                child: BuyPill(onTap: () => openProductLink(context, buyUrl)),
              ),
          ],
        ),
      ),
    );
    if (buyUrl != null) {
      tile = GestureDetector(
        onTap: () => openProductLink(context, buyUrl),
        child: tile,
      );
    }
    return Semantics(
      image: true,
      label: [?name, if (more > 0) 'and $more more'].join(' '),
      child: tile,
    );
  }
}
