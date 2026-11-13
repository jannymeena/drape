import 'flat_lay_layouts.dart';

/// Where each piece of an outfit goes in its picture, and on which surface.
///
/// Pure and deterministic: the same pieces and [FlatLayPlan.seed] (the
/// outfit's id) always give the same picture, so a card never reshuffles on
/// a rebuild or a refresh — different outfits still get different layouts.
class FlatLayPlan {
  const FlatLayPlan({
    required this.variant,
    required this.variantIndex,
    required this.order,
    required this.background,
  });

  /// The slots used, largest first.
  final FlatLayVariant variant;

  /// Which of the count's variants it is (for tests and debugging).
  final int variantIndex;

  /// `order[i]` = the index (into the pieces given) of the piece in slot `i`.
  final List<int> order;

  /// The background asset.
  final String background;

  static const _empty = FlatLayPlan(
    variant: [],
    variantIndex: 0,
    order: [],
    background: '',
  );

  /// Plans [priorities] (one per piece, as given) for the outfit [seed].
  ///
  /// 1. Pieces are sorted by priority, highest first (ties keep their given
  ///    order); past [flatLayMaxPieces] the lowest are left out.
  /// 2. Of the variants for that many pieces, the ones whose slot sizes
  ///    follow the priorities best win ([fitScore]): tied pieces in equal
  ///    slots, different ones in different-sized slots.
  /// 3. Among those, the seed picks one; it also picks the background.
  static FlatLayPlan of(List<int> priorities, {required String seed}) {
    if (priorities.isEmpty) return _empty;
    final ranked = [for (var i = 0; i < priorities.length; i++) i]
      ..sort((a, b) {
        final byPriority = priorities[b].compareTo(priorities[a]);
        return byPriority != 0 ? byPriority : a.compareTo(b);
      });
    final order = ranked.take(flatLayMaxPieces).toList();
    final sorted = [for (final i in order) priorities[i]];

    final variants = flatLayVariants[order.length]!;
    final scores = [for (final v in variants) fitScore(sorted, v)];
    final best = scores.reduce((a, b) => a > b ? a : b);
    final candidates = [
      for (var i = 0; i < variants.length; i++)
        if (scores[i] == best) i,
    ];
    final pick = candidates[_hash('$seed/layout') % candidates.length];

    return FlatLayPlan(
      variant: variants[pick],
      variantIndex: pick,
      order: order,
      background:
          flatLayBackgrounds[_hash('$seed/background') %
              flatLayBackgrounds.length],
    );
  }

  /// How well [variant]'s slot sizes follow [sorted] (the priorities in
  /// slot order, highest first), pair by pair down the list: two tied
  /// pieces in equal slots +1; two different pieces made the same size −1
  /// (the bigger number should get the bigger area). Anything else 0.
  static int fitScore(List<int> sorted, FlatLayVariant variant) {
    var score = 0;
    for (var i = 1; i < sorted.length; i++) {
      final equalSlots = _sameSize(variant[i], variant[i - 1]);
      if (!equalSlots) continue;
      score += sorted[i] == sorted[i - 1] ? 1 : -1;
    }
    return score;
  }

  static bool _sameSize(FlatLaySlot a, FlatLaySlot b) =>
      (a.area - b.area).abs() < 1e-6;

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
