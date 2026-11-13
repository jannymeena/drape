import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/widgets/flat_lay/flat_lay_layouts.dart';
import 'package:mobile/modules/today/widgets/flat_lay/flat_lay_plan.dart';

void main() {
  group('layout tables', () {
    test('three variants for every count from 1 to 10', () {
      for (var n = 1; n <= flatLayMaxPieces; n++) {
        final variants = flatLayVariants[n];
        expect(variants, isNotNull, reason: '$n pieces');
        expect(variants!.length, 3, reason: '$n pieces');
        for (final v in variants) {
          expect(v.length, n, reason: '$n pieces');
        }
      }
    });

    test('slots run largest first and stay on the picture', () {
      flatLayVariants.forEach((n, variants) {
        for (final (vi, v) in variants.indexed) {
          for (var i = 1; i < v.length; i++) {
            expect(
              v[i].area,
              lessThanOrEqualTo(v[i - 1].area + 1e-9),
              reason: '$n pieces, variant $vi, slot $i',
            );
          }
          for (final s in v) {
            expect(s.x, greaterThanOrEqualTo(0));
            expect(s.y, greaterThanOrEqualTo(0));
            expect(s.x + s.w, lessThanOrEqualTo(1.0 + 1e-9));
            expect(s.y + s.h, lessThanOrEqualTo(1.0 + 1e-9));
          }
        }
      });
    });

    test('ten backgrounds', () {
      expect(flatLayBackgrounds.length, 10);
      expect(flatLayBackgrounds.toSet().length, 10);
    });
  });

  group('plan', () {
    test('biggest priority gets the biggest slot', () {
      // Shoes, coat, watch, as they came.
      final plan = FlatLayPlan.of([400, 900, 100], seed: 'o1');
      expect(plan.order, [1, 0, 2]);
      expect(plan.variant.length, 3);
    });

    test('ties keep the order they came in', () {
      final plan = FlatLayPlan.of([600, 900, 600], seed: 'o1');
      expect(plan.order, [1, 0, 2]);
    });

    test('a top and its trousers get equal slots', () {
      // Top, bottom, shoes: only the [M, M, S] variant seats the tie.
      for (final seed in ['a', 'b', 'c', 'd', 'e', 'f']) {
        final plan = FlatLayPlan.of([600, 600, 400], seed: seed);
        expect(
          (plan.variant[0].area - plan.variant[1].area).abs(),
          lessThan(1e-9),
          reason: seed,
        );
      }
    });

    test('a coat over a tied top and trousers: equal pair under the hero', () {
      final plan = FlatLayPlan.of([600, 900, 600, 400, 200], seed: 'x');
      expect(plan.order.first, 1); // the coat
      expect(
        (plan.variant[1].area - plan.variant[2].area).abs(),
        lessThan(1e-9),
      );
    });

    test('the same outfit always gets the same picture', () {
      final a = FlatLayPlan.of([900, 600, 600, 400], seed: 'outfit-42');
      final b = FlatLayPlan.of([900, 600, 600, 400], seed: 'outfit-42');
      expect(a.variantIndex, b.variantIndex);
      expect(a.background, b.background);
      expect(a.order, b.order);
    });

    test(
      'different pieces never get the same size when a variant avoids it',
      () {
        // Coat and shoes: only the hero + smaller variant keeps them apart.
        for (final seed in ['a', 'b', 'c', 'd', 'e', 'f']) {
          final plan = FlatLayPlan.of([900, 400], seed: seed);
          expect(plan.variant[0].area, greaterThan(plan.variant[1].area));
        }
      },
    );

    test('different outfits get different variants and surfaces', () {
      // One piece: every variant fits as well, so the seed decides.
      final variants = <int>{};
      final backgrounds = <String>{};
      for (var i = 0; i < 60; i++) {
        final plan = FlatLayPlan.of([700], seed: 'outfit-$i');
        variants.add(plan.variantIndex);
        backgrounds.add(plan.background);
      }
      expect(variants, {0, 1, 2});
      expect(backgrounds.length, greaterThan(6));
    });

    test('past ten pieces the lowest priorities are left out', () {
      final priorities = [for (var i = 0; i < 12; i++) 100 + i * 10];
      final plan = FlatLayPlan.of(priorities, seed: 's');
      expect(plan.order.length, 10);
      expect(plan.order, isNot(contains(0)));
      expect(plan.order, isNot(contains(1)));
    });

    test('no pieces, no plan', () {
      expect(FlatLayPlan.of([], seed: 's').order, isEmpty);
    });
  });

  group('fit score', () {
    const pair = [FlatLaySlot(0, 0, .4, .5), FlatLaySlot(.5, 0, .4, .5)];
    const uneven = [FlatLaySlot(0, 0, .6, .6), FlatLaySlot(.6, 0, .3, .3)];

    test('rewards ties in equal slots, penalises equal slots for unequals', () {
      expect(FlatLayPlan.fitScore([600, 600], pair), 1);
      expect(FlatLayPlan.fitScore([600, 600], uneven), 0);
      expect(FlatLayPlan.fitScore([900, 600], uneven), 0);
      expect(FlatLayPlan.fitScore([900, 600], pair), -1);
    });
  });
}
