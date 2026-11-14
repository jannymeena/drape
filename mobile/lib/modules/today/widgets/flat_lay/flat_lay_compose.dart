/// Where each piece of an outfit goes in its picture, composed the way a
/// stylist lays a flat-lay out by hand:
///
/// * every piece at its **real-world size** (a folded coat is wider than a
///   folded sweater; a watch is small) — one scale for the whole picture,
///   never a piece blown up to fill a box. The one give: pieces sharing a
///   row are evened up to the row's height (by at most [_rowEvenUp]), so a
///   sweater and trousers side by side read as a tidy pair;
/// * the pieces in **rows** with one tight gap, each row's tops lined up and
///   the rows centred over each other — the main piece (the coat) leads the
///   top row;
/// * the **shoes tucked over the trousers**: overlapping their outer edge
///   and hanging below their hem, as a pair would be set down;
/// * small things (a watch, jewellery, a belt) in a **column at the edge**,
///   level with the bottom of the picture.
///
/// Every split of the pieces into rows is tried; the one that fills the
/// picture best wins (splitting a tied top and trousers costs a little). The
/// outfit's id ([seed]) picks among the near-best ones and mirrors the
/// picture or not — so an outfit always looks the same and different
/// outfits don't all look alike. Every picture is on the same linen sheet.
///
/// Pure: no widgets, so it is tested on its own.
library;

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

/// One piece to lay out.
class FlatLayPiece {
  const FlatLayPiece({
    required this.category,
    required this.priority,
    this.aspect,
  });

  /// Wardrobe category (`tops`, `shoes`, …) — sets its real-world size and
  /// its role.
  final String category;

  /// Dress priority (0–1000): the order pieces are laid in; the highest
  /// leads the top row.
  final int priority;

  /// The piece's own width ÷ height (from its cut-out's box); null when it
  /// isn't known (a shop photo), then a typical shape for the category.
  final double? aspect;
}

/// Where piece [index] (into the pieces given) is drawn, in the picture's
/// own pixels.
class FlatLayPlacement {
  const FlatLayPlacement(this.index, this.rect);
  final int index;
  final Rect rect;

  @override
  String toString() => 'FlatLayPlacement($index, $rect)';
}

class FlatLayComposition {
  const FlatLayComposition({
    required this.placements,
    required this.background,
    required this.mirrored,
    required this.rowCount,
  });

  /// In drawing order: the rows from the top, then the shoes (over the
  /// trousers), then the edge column.
  final List<FlatLayPlacement> placements;

  /// The surface asset.
  final String background;

  /// Laid out right-to-left (edge column on the left).
  final bool mirrored;

  /// How many rows the main pieces are in (for tests).
  final int rowCount;

  /// Lays out [pieces] in a picture of [size] for the outfit [seed].
  static FlatLayComposition of(
    List<FlatLayPiece> pieces, {
    required String seed,
    required Size size,
  }) {
    final background =
        flatLayBackgrounds[_hash('$seed/background') %
            flatLayBackgrounds.length];
    final mirrored = _hash('$seed/mirror').isOdd;
    if (pieces.isEmpty || size.isEmpty) {
      return FlatLayComposition(
        placements: const [],
        background: background,
        mirrored: mirrored,
        rowCount: 0,
      );
    }

    // Highest priority first; ties keep the order they came in.
    final ranked = [for (var i = 0; i < pieces.length; i++) i]
      ..sort((a, b) {
        final byPriority = pieces[b].priority.compareTo(pieces[a].priority);
        return byPriority != 0 ? byPriority : a.compareTo(b);
      });
    final items = [
      for (final i in ranked.take(flatLayMaxPieces)) _Item.of(i, pieces[i]),
    ];

    // Roles: the edge column, the shoes tucked over the trousers, the rest
    // in rows. Without anything for the rows, the shoes and then the small
    // things go in them.
    var column = [
      for (final it in items)
        if (_columnCategories.contains(it.category)) it,
    ];
    _Item? tucked;
    final rowItems = <_Item>[];
    for (final it in items) {
      if (column.contains(it)) continue;
      if (tucked == null && it.category == 'shoes') {
        tucked = it;
      } else {
        rowItems.add(it);
      }
    }
    if (rowItems.isEmpty && tucked != null) {
      rowItems.add(tucked);
      tucked = null;
    }
    if (rowItems.isEmpty) {
      rowItems.addAll(column);
      column = [];
    }

    final options = [
      for (final rows in _splits(rowItems, maxRows: _maxRows))
        _Layout.build(rows, tucked: tucked, column: column, frame: size),
    ];
    final best = options.map((o) => o.score).reduce(math.max);
    final near = [
      for (final o in options)
        if (o.score >= best * _nearBest) o,
    ];
    final pick = near[_hash('$seed/layout') % near.length];

    return FlatLayComposition(
      placements: pick.place(size, mirrored: mirrored),
      background: background,
      mirrored: mirrored,
      rowCount: pick.rows.length,
    );
  }

  /// FNV-1a over the UTF-16 code units: stable across runs and platforms
  /// (unlike `String.hashCode`), so a picture looks the same everywhere.
  static int _hash(String s) {
    var h = 0x811c9dc5;
    for (final unit in s.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xffffffff;
    }
    return h;
  }
}

/// The most pieces a picture shows; past this the lowest-priority ones are
/// left out.
const int flatLayMaxPieces = 10;

/// The surface every picture is laid on (`assets/outfit_backgrounds/`): a
/// pale linen sheet with soft fold creases. A list so more can be added;
/// the seed picks one.
const List<String> flatLayBackgrounds = [
  'assets/outfit_backgrounds/bg_linen_sheet.webp',
];

/// The longer side of each kind of piece as it lies folded, in cm — what
/// keeps a coat bigger than a shirt and a watch small.
const Map<String, double> flatLayLongSideCm = {
  'outerwear': 50,
  'dresses': 52,
  'tops': 36,
  'bottoms': 38,
  'shoes': 28,
  'bags': 30,
  'accessories': 20,
  'jewelry': 15,
};
const double _defaultLongSideCm = 32;

/// Typical width ÷ height when a piece's own shape isn't known.
const Map<String, double> _typicalAspect = {
  'outerwear': 1.3,
  'dresses': 0.65,
  'tops': 1.0,
  'bottoms': 0.72,
  'shoes': 0.85,
  'bags': 1.0,
  'accessories': 0.6,
  'jewelry': 0.6,
};
const double _defaultAspect = 0.9;

/// Small things that go in the edge column.
const Set<String> _columnCategories = {'accessories', 'jewelry'};

/// Gap between pieces, cm.
const double _gapCm = 1.0;

/// Empty border round the picture, as a share of its shorter side.
const double _margin = 0.03;

/// How far the shoes overlap the trousers' outer edge (share of the
/// shoes' width), and how much of them hangs below the hem (share of their
/// height).
const double _tuckOverlap = 0.35;
const double _tuckDrop = 0.3;

/// The most a piece is enlarged to match the tallest piece in its row.
const double _rowEvenUp = 1.2;

/// Layouts filling at least this share of the best one's are all fair game.
const double _nearBest = 0.93;

/// What splitting a tied pair (a top and its trousers) across rows costs.
const double _splitTiePenalty = 0.88;

const int _maxRows = 3;

class _Item {
  _Item(this.index, this.category, this.priority, this.w, this.h);

  factory _Item.of(int index, FlatLayPiece p) {
    final category = p.category.trim().toLowerCase();
    final long = flatLayLongSideCm[category] ?? _defaultLongSideCm;
    final raw = p.aspect;
    final aspect = raw != null && raw.isFinite && raw > 0
        ? raw
        : _typicalAspect[category] ?? _defaultAspect;
    return aspect >= 1
        ? _Item(index, category, p.priority, long, long / aspect)
        : _Item(index, category, p.priority, long * aspect, long);
  }

  final int index;
  final String category;
  final int priority;

  /// Real-world size, cm.
  final double w, h;

  /// This piece made [k] times bigger, same shape.
  _Item scaled(double k) => _Item(index, category, priority, w * k, h * k);
}

/// Every way to cut [items] (in order) into 1 to [maxRows] rows.
Iterable<List<List<_Item>>> _splits(
  List<_Item> items, {
  required int maxRows,
}) sync* {
  final n = items.length;
  // A bit set over the n-1 places a row could end.
  for (var mask = 0; mask < 1 << (n - 1); mask++) {
    final cuts = _bitCount(mask);
    if (cuts + 1 > maxRows) continue;
    final rows = <List<_Item>>[[]];
    for (var i = 0; i < n; i++) {
      rows.last.add(items[i]);
      if (i < n - 1 && mask & (1 << i) != 0) rows.add([]);
    }
    yield rows;
  }
}

int _bitCount(int v) {
  var c = 0;
  for (; v != 0; v &= v - 1) {
    c++;
  }
  return c;
}

/// One candidate arrangement, in cm, with how well it fills the picture.
class _Layout {
  _Layout(this.rows, this.rects, this.width, this.height, this.score);

  final List<List<_Item>> rows;

  /// Piece index → its rect in cm, from the content's top-left, in drawing
  /// order.
  final List<(int, Rect)> rects;
  final double width, height;
  final double score;

  static _Layout build(
    List<List<_Item>> rows, {
    required _Item? tucked,
    required List<_Item> column,
    required Size frame,
  }) {
    // The shoes go at the end of the trousers' row (else the last row);
    // the trousers move to the end of their row to meet them.
    var tuckRow = rows.length - 1;
    for (var r = 0; r < rows.length; r++) {
      if (rows[r].any((it) => it.category == 'bottoms')) tuckRow = r;
    }

    final rowRects = <List<(int, Rect)>>[];
    final rowWidths = <double>[];
    final rowTops = <double>[];
    var y = 0.0;
    (int, Rect)? tuck;
    for (var r = 0; r < rows.length; r++) {
      final natural = [
        ...rows[r].where((it) => it.category != 'bottoms'),
        ...rows[r].where((it) => it.category == 'bottoms'),
      ];
      // Even the row up: each piece towards the tallest one's height.
      final tallest = natural.map((it) => it.h).reduce(math.max);
      final ordered = [
        for (final it in natural)
          it.scaled(math.min(_rowEvenUp, tallest / it.h)),
      ];
      final placed = <(int, Rect)>[];
      var x = 0.0;
      var rowH = 0.0;
      for (final it in ordered) {
        placed.add((it.index, Rect.fromLTWH(x, y, it.w, it.h)));
        x += it.w + _gapCm;
        rowH = math.max(rowH, it.h);
      }
      var rowW = x - _gapCm;
      if (r == tuckRow && tucked != null) {
        // Over the outer edge of the row's last piece (the trousers, when
        // the row has them), hanging below its hem.
        final last = placed.last.$2;
        final sx = last.right - tucked.w * _tuckOverlap;
        final sy = math.max(y, last.bottom - tucked.h * (1 - _tuckDrop));
        tuck = (tucked.index, Rect.fromLTWH(sx, sy, tucked.w, tucked.h));
        rowW = math.max(rowW, sx + tucked.w);
        rowH = math.max(rowH, sy + tucked.h - y);
      }
      rowRects.add(placed);
      rowWidths.add(rowW);
      rowTops.add(y);
      y += rowH + _gapCm;
    }
    final mainH = y - _gapCm;
    final mainW = rowWidths.reduce(math.max);

    // The edge column: stacked, centred in its width, level with the bottom.
    final colW = column.isEmpty
        ? 0.0
        : column.map((it) => it.w).reduce(math.max);
    final colH = column.isEmpty
        ? 0.0
        : column.map((it) => it.h).reduce((a, b) => a + b) +
              _gapCm * (column.length - 1);
    final height = math.max(mainH, colH);
    final width = column.isEmpty ? mainW : mainW + _gapCm + colW;
    final mainDy = (height - mainH) / 2;

    final rects = <(int, Rect)>[];
    for (var r = 0; r < rows.length; r++) {
      final dx = (mainW - rowWidths[r]) / 2;
      for (final (i, rect) in rowRects[r]) {
        rects.add((i, rect.shift(Offset(dx, mainDy))));
      }
      if (r == tuckRow && tuck != null) {
        // Shifted with its row; drawn after every row (below).
        tuck = (tuck.$1, tuck.$2.shift(Offset(dx, mainDy)));
      }
    }
    if (tuck != null) rects.add(tuck);
    var cy = height - colH;
    for (final it in column) {
      final cx = mainW + _gapCm + (colW - it.w) / 2;
      rects.add((it.index, Rect.fromLTWH(cx, cy, it.w, it.h)));
      cy += it.h + _gapCm;
    }

    // Fill: the pieces' share of the picture at the scale that fits.
    final avail = _available(frame);
    final scale = math.min(avail.width / width, avail.height / height);
    var covered = 0.0;
    for (final (_, rect) in rects) {
      covered += rect.width * rect.height;
    }
    var score = covered * scale * scale / (frame.width * frame.height);
    // A tied pair split across rows reads as two outfits.
    for (var r = 1; r < rows.length; r++) {
      if (rows[r - 1].last.priority == rows[r].first.priority) {
        score *= _splitTiePenalty;
      }
    }
    return _Layout(rows, rects, width, height, score);
  }

  /// The rects in the picture's pixels: scaled to fit inside the margin,
  /// centred, mirrored if asked.
  List<FlatLayPlacement> place(Size frame, {required bool mirrored}) {
    final avail = _available(frame);
    final scale = math.min(avail.width / width, avail.height / height);
    final ox = (frame.width - width * scale) / 2;
    final oy = (frame.height - height * scale) / 2;
    return [
      for (final (i, r) in rects)
        FlatLayPlacement(
          i,
          Rect.fromLTWH(
            mirrored
                ? frame.width - ox - (r.left + r.width) * scale
                : ox + r.left * scale,
            oy + r.top * scale,
            r.width * scale,
            r.height * scale,
          ),
        ),
    ];
  }

  static Size _available(Size frame) {
    final m = _margin * math.min(frame.width, frame.height);
    return Size(frame.width - 2 * m, frame.height - 2 * m);
  }
}
