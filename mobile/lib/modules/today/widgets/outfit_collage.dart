import 'dart:ui' show ImageFilter;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buy_pill.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import 'flat_lay/flat_lay_layouts.dart';
import 'flat_lay/flat_lay_plan.dart';

/// One garment in an outfit picture.
///
/// [cutoutUrl] + [cutoutBox] are the piece alone on a transparent square
/// (with where it sits on it) — what the picture is made of. Without them
/// (shop products) the piece shows as its [imageUrl] photo, unframed, or a
/// [GarmentPlaceholder] drawn from [category] + [color]. [priority] (dress priority, 0–1000) decides how
/// big a slot it gets. [buyUrl] is set for pieces the user doesn't own
/// (AWIN products): the piece gets a "Buy" pill.
class GarmentCell {
  final String? imageUrl;
  final String? cutoutUrl;
  final List<double>? cutoutBox;
  final int priority;
  final String category;
  final Color? color;
  final String? buyUrl;

  const GarmentCell({
    this.imageUrl,
    this.cutoutUrl,
    this.cutoutBox,
    this.priority = 500,
    required this.category,
    this.color,
    this.buyUrl,
  });

  bool get hasCutout => cutoutUrl != null && cutoutBox?.length == 4;
}

/// An outfit's picture, composed on the device as a flat-lay: the pieces
/// laid on one of the bundled surfaces, in one of the layouts for that many
/// pieces (flat_lay_layouts.dart), biggest piece in the biggest slot.
///
/// [seed] (the outfit's id) fixes the layout variant and surface, so the
/// same outfit always looks the same. Everything is straight — no tilt, no
/// frames: transparent cut-outs with one soft drawn shadow each, so pieces
/// made separately lie on the surface together like on a table.
class OutfitCollage extends StatelessWidget {
  final List<GarmentCell> cells;
  final String seed;
  final double height;

  const OutfitCollage({
    super.key,
    required this.cells,
    required this.seed,
    this.height = 260,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ColoredBox(
          color: AppColors.ivoryWarm,
          child: cells.isEmpty
              ? const SizedBox.expand()
              : LayoutBuilder(builder: (context, box) => _scene(box.biggest)),
        ),
      ),
    );
  }

  Widget _scene(Size size) {
    final plan = FlatLayPlan.of([
      for (final c in cells) c.priority,
    ], seed: seed);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Image.asset(
            plan.background,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
        // Largest first, so smaller pieces overlap bigger ones.
        for (var i = 0; i < plan.order.length; i++)
          _place(cells[plan.order[i]], plan.variant[i], size),
      ],
    );
  }

  Widget _place(GarmentCell cell, FlatLaySlot slot, Size size) {
    final rect = Rect.fromLTWH(
      slot.x * size.width,
      slot.y * size.height,
      slot.w * size.width,
      slot.h * size.height,
    );
    if (cell.hasCutout) return _CutoutPiece.positioned(cell, rect);
    return Positioned.fromRect(rect: rect, child: _PlainPiece(cell));
  }
}

/// A cut-out fitted (whole, not cropped) into its slot by the piece's own
/// outline, with a soft shadow and a contact shadow under it — lying on
/// the surface.
class _CutoutPiece extends StatelessWidget {
  final GarmentCell cell;
  final double side;

  const _CutoutPiece(this.cell, this.side);

  /// The cut-out's square, positioned so the piece inside it fills [slot]
  /// as far as its proportions allow, centred.
  static Widget positioned(GarmentCell cell, Rect slot) {
    final [bx, by, bw, bh] = cell.cutoutBox!;
    final aspect = bw / bh;
    final double pw, ph;
    if (slot.width / slot.height > aspect) {
      ph = slot.height;
      pw = ph * aspect;
    } else {
      pw = slot.width;
      ph = pw / aspect;
    }
    final side = pw / bw; // the whole square, at this scale
    final piece = Rect.fromCenter(center: slot.center, width: pw, height: ph);
    return Positioned(
      left: piece.left - bx * side,
      top: piece.top - by * side,
      width: side,
      height: side,
      child: _CutoutPiece(cell, side),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = cell.cutoutUrl!;
    final image = CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.fill,
      width: side,
      height: side,
      fadeInDuration: const Duration(milliseconds: 150),
      // Couldn't load the cut-out: the plain photo instead.
      errorWidget: (_, _, _) => _PlainPiece(cell),
    );
    // Two shadows, as a folded piece casts on cloth — the light from the
    // upper left, same as the piece's own shading:
    //   * a soft, wide one falling down-right (its height off the cloth);
    //   * a tight, darker one hugging the edge (where it touches).
    Widget shadow({
      required double alpha,
      required double blur,
      required Offset offset,
    }) => Transform.translate(
      offset: offset * side,
      child: ImageFiltered(
        imageFilter: _blur(side * blur),
        child: ColorFiltered(
          colorFilter: ColorFilter.mode(
            AppColors.espressoDeep.withValues(alpha: alpha),
            BlendMode.srcIn,
          ),
          child: CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.fill,
            width: side,
            height: side,
            fadeInDuration: Duration.zero,
            errorWidget: (_, _, _) => const SizedBox.shrink(),
          ),
        ),
      ),
    );
    return _Buyable(
      cell,
      child: Stack(
        children: [
          shadow(alpha: 0.25, blur: 0.025, offset: const Offset(0.012, 0.028)),
          shadow(alpha: 0.38, blur: 0.005, offset: const Offset(0.003, 0.006)),
          image,
        ],
      ),
    );
  }
}

/// A piece without a cut-out (a shop product — its feed photo is shown
/// unaltered): the photo itself, fitted whole into the slot, no frame.
class _PlainPiece extends StatelessWidget {
  final GarmentCell cell;
  const _PlainPiece(this.cell);

  @override
  Widget build(BuildContext context) {
    final placeholder = GarmentPlaceholder(
      category: cell.category,
      color: cell.color,
    );
    final url = cell.imageUrl;
    return _Buyable(
      cell,
      showPill: true,
      child: url == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorWidget: (_, _, _) => placeholder,
            ),
    );
  }
}

/// A shop piece opens its product page when tapped; a plain one also
/// carries the Buy pill (where it fits).
class _Buyable extends StatelessWidget {
  final GarmentCell cell;
  final Widget child;
  final bool showPill;
  const _Buyable(this.cell, {required this.child, this.showPill = false});

  @override
  Widget build(BuildContext context) {
    final url = cell.buyUrl;
    if (url == null) return child;
    void open() => openProductLink(context, url);
    return GestureDetector(
      onTap: open,
      child: !showPill
          ? child
          : LayoutBuilder(
              builder: (context, box) => Stack(
                fit: StackFit.expand,
                children: [
                  child,
                  if (box.maxWidth >= 64)
                    Positioned(top: 4, left: 4, child: BuyPill(onTap: open)),
                ],
              ),
            ),
    );
  }
}

ImageFilter _blur(double sigma) =>
    ImageFilter.blur(sigmaX: sigma, sigmaY: sigma, tileMode: TileMode.decal);
