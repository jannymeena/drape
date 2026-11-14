import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/widgets/flat_lay/flat_lay_compose.dart';

const _frame = Size(360, 260);

const _coat = FlatLayPiece(category: 'outerwear', priority: 900, aspect: 1.35);
const _sweater = FlatLayPiece(category: 'tops', priority: 600, aspect: 1.0);
const _trousers = FlatLayPiece(category: 'bottoms', priority: 600, aspect: 0.7);
const _boots = FlatLayPiece(category: 'shoes', priority: 400, aspect: 0.8);
const _watch = FlatLayPiece(category: 'jewelry', priority: 100, aspect: 0.3);
const _belt = FlatLayPiece(category: 'accessories', priority: 200, aspect: 0.5);
const _bag = FlatLayPiece(category: 'bags', priority: 300, aspect: 1.1);
const _dress = FlatLayPiece(category: 'dresses', priority: 800, aspect: 0.6);

/// The reference flat-lay: coat, sweater, trousers, boots, watch.
const _reference = [_sweater, _coat, _trousers, _boots, _watch];

Rect _rectOf(FlatLayComposition c, int index) =>
    c.placements.firstWhere((p) => p.index == index).rect;

bool _overlaps(Rect a, Rect b) =>
    a.intersect(b).width > 0.5 && a.intersect(b).height > 0.5;

void main() {
  test('the reference: coat on top, sweater + trousers under it, boots '
      'over the trousers, watch at the edge', () {
    for (final seed in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h']) {
      final c = FlatLayComposition.of(_reference, seed: seed, size: _frame);
      final coat = _rectOf(c, 1);
      final sweater = _rectOf(c, 0);
      final trousers = _rectOf(c, 2);
      final boots = _rectOf(c, 3);
      final watch = _rectOf(c, 4);

      expect(c.rowCount, 2, reason: seed);
      // Coat above the row; sweater and trousers side by side, tops level.
      expect(coat.bottom, lessThanOrEqualTo(sweater.top + 0.01), reason: seed);
      expect(sweater.top, closeTo(trousers.top, 0.01), reason: seed);
      expect(_overlaps(sweater, trousers), isFalse, reason: seed);
      // Boots overlap the trousers (not the sweater) and hang below them.
      expect(_overlaps(boots, trousers), isTrue, reason: seed);
      expect(_overlaps(boots, sweater), isFalse, reason: seed);
      expect(boots.bottom, greaterThan(trousers.bottom), reason: seed);
      // The watch is the outermost piece, on the side the boots face.
      final pieces = [coat, sweater, trousers, boots];
      if (c.mirrored) {
        expect(
          watch.right,
          lessThanOrEqualTo(
            pieces.map((r) => r.left).reduce((a, b) => a < b ? a : b) + 0.01,
          ),
        );
      } else {
        expect(
          watch.left,
          greaterThanOrEqualTo(
            pieces.map((r) => r.right).reduce((a, b) => a > b ? a : b) - 0.01,
          ),
        );
      }
      // Drawn after what they overlap.
      final order = [for (final p in c.placements) p.index];
      expect(order.indexOf(3), greaterThan(order.indexOf(2)));
      expect(order.last, 4);
    }
  });

  test('one scale for the whole picture: real-world sizes', () {
    final c = FlatLayComposition.of(_reference, seed: 's', size: _frame);
    final coat = _rectOf(c, 1);
    final sweater = _rectOf(c, 0);
    final boots = _rectOf(c, 3);
    final watch = _rectOf(c, 4);
    expect(coat.width, greaterThan(sweater.width));
    expect(boots.height, lessThan(sweater.height));
    expect(watch.height, lessThan(boots.height));
    // Long sides keep the table's ratios, give or take evening up a row.
    double long(Rect r) => r.width > r.height ? r.width : r.height;
    final real = flatLayLongSideCm['outerwear']! / flatLayLongSideCm['tops']!;
    expect(long(coat) / long(sweater), inInclusiveRange(real / 1.2, real));
  });

  test('every piece keeps its own shape', () {
    final c = FlatLayComposition.of(_reference, seed: 's', size: _frame);
    for (final p in c.placements) {
      final aspect = _reference[p.index].aspect!;
      expect(p.rect.width / p.rect.height, closeTo(aspect, 1e-6));
    }
  });

  test('everything stays inside the picture, at any size and mix', () {
    const mixes = [
      [_coat],
      [_sweater, _trousers],
      [_dress, _boots, _bag, _watch],
      [_coat, _sweater, _trousers, _boots, _bag, _belt, _watch],
      [
        _coat,
        _sweater,
        _sweater,
        _trousers,
        _trousers,
        _boots,
        _boots,
        _bag,
        _belt,
        _watch,
      ],
      [_watch, _belt],
      [_boots],
    ];
    const sizes = [
      Size(360, 260),
      Size(170, 220),
      Size(400, 640),
      Size(300, 300),
    ];
    for (final mix in mixes) {
      for (final size in sizes) {
        final c = FlatLayComposition.of(mix, seed: 'm', size: size);
        expect(c.placements.length, mix.length);
        expect({for (final p in c.placements) p.index}.length, mix.length);
        for (final p in c.placements) {
          expect(p.rect.left, greaterThanOrEqualTo(-1e-6), reason: '$size');
          expect(p.rect.top, greaterThanOrEqualTo(-1e-6), reason: '$size');
          expect(
            p.rect.right,
            lessThanOrEqualTo(size.width + 1e-6),
            reason: '$size',
          );
          expect(
            p.rect.bottom,
            lessThanOrEqualTo(size.height + 1e-6),
            reason: '$size',
          );
        }
      }
    }
  });

  test('only the shoes overlap anything', () {
    const mix = [_coat, _sweater, _trousers, _boots, _bag, _belt, _watch];
    for (final seed in ['a', 'b', 'c', 'd']) {
      final c = FlatLayComposition.of(mix, seed: seed, size: _frame);
      final flat = [
        for (final p in c.placements)
          if (p.index != 3) p.rect,
      ];
      for (var i = 0; i < flat.length; i++) {
        for (var j = i + 1; j < flat.length; j++) {
          expect(_overlaps(flat[i], flat[j]), isFalse, reason: '$seed $i $j');
        }
      }
    }
  });

  test('the picture is filled, not left mostly bare', () {
    final c = FlatLayComposition.of(_reference, seed: 's', size: _frame);
    final covered = c.placements
        .map((p) => p.rect.width * p.rect.height)
        .reduce((a, b) => a + b);
    expect(covered / (_frame.width * _frame.height), greaterThan(0.3));
  });

  test('the same outfit always gets the same picture', () {
    final a = FlatLayComposition.of(
      _reference,
      seed: 'outfit-42',
      size: _frame,
    );
    final b = FlatLayComposition.of(
      _reference,
      seed: 'outfit-42',
      size: _frame,
    );
    expect(a.background, b.background);
    expect(a.mirrored, b.mirrored);
    expect(
      [for (final p in a.placements) p.rect],
      [for (final p in b.placements) p.rect],
    );
  });

  test('every outfit is on the linen sheet; sides vary', () {
    final backgrounds = <String>{};
    final sides = <bool>{};
    for (var i = 0; i < 60; i++) {
      final c = FlatLayComposition.of(
        _reference,
        seed: 'outfit-$i',
        size: _frame,
      );
      backgrounds.add(c.background);
      sides.add(c.mirrored);
    }
    expect(backgrounds, {'assets/outfit_backgrounds/bg_linen_sheet.webp'});
    expect(sides, {true, false});
  });

  test('past ten pieces the lowest priorities are left out', () {
    final pieces = [
      for (var i = 0; i < 12; i++)
        FlatLayPiece(category: 'tops', priority: 100 + i * 10, aspect: 1),
    ];
    final c = FlatLayComposition.of(pieces, seed: 's', size: _frame);
    final shown = {for (final p in c.placements) p.index};
    expect(shown.length, flatLayMaxPieces);
    expect(shown, isNot(contains(0)));
    expect(shown, isNot(contains(1)));
  });

  test('unknown shapes and categories still lay out', () {
    const pieces = [
      FlatLayPiece(category: 'tops', priority: 600),
      FlatLayPiece(category: 'scarves', priority: 500, aspect: double.nan),
    ];
    final c = FlatLayComposition.of(pieces, seed: 's', size: _frame);
    expect(c.placements.length, 2);
  });

  test('no pieces, nothing placed', () {
    expect(
      FlatLayComposition.of([], seed: 's', size: _frame).placements,
      isEmpty,
    );
  });

  test(
    'a row is evened up: sweater and trousers side by side match height',
    () {
      final c = FlatLayComposition.of(_reference, seed: 's', size: _frame);
      expect(_rectOf(c, 0).height, closeTo(_rectOf(c, 2).height, 0.01));
    },
  );
}
