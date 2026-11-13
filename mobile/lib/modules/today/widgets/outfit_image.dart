import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'outfit_collage.dart';

/// An outfit's picture: its photo when it has one ([imageUrl] — a network
/// URL, or a bundled `assets/...` path for the debug sample cards), else the
/// client-side flat-lay of its pieces ([seed] = the outfit's id). Fills the
/// space it's given.
class OutfitImage extends StatelessWidget {
  final String? imageUrl;
  final List<GarmentCell> cells;
  final String seed;

  const OutfitImage({
    super.key,
    this.imageUrl,
    required this.cells,
    required this.seed,
  });

  @override
  Widget build(BuildContext context) {
    final collage = OutfitCollage(
      cells: cells,
      seed: seed,
      height: double.infinity,
    );
    final url = imageUrl;
    if (url == null || url.isEmpty) return collage;
    if (url.startsWith('assets/')) {
      return Image.asset(
        url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, _, _) => collage,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorWidget: (_, _, _) => collage,
    );
  }
}
