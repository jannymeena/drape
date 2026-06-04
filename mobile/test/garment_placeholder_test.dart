import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/garment_placeholder.dart';

void main() {
  group('garmentColorFromHex', () {
    test('parses #RRGGBB with full opacity', () {
      expect(garmentColorFromHex('#3B5C8C'), const Color(0xFF3B5C8C));
    });

    test('parses without leading hash and #AARRGGBB', () {
      expect(garmentColorFromHex('3B5C8C'), const Color(0xFF3B5C8C));
      expect(garmentColorFromHex('#803B5C8C'), const Color(0x803B5C8C));
    });

    test('null / malformed → null', () {
      expect(garmentColorFromHex(null), isNull);
      expect(garmentColorFromHex('nope'), isNull);
      expect(garmentColorFromHex('#12'), isNull);
    });
  });

  group('garmentColorFromName', () {
    test('known names resolve (case-insensitive)', () {
      expect(garmentColorFromName('blue'), isNotNull);
      expect(garmentColorFromName('Black'), isNotNull);
      expect(garmentColorFromName('  White '), isNotNull);
    });

    test('unknown / null → null', () {
      expect(garmentColorFromName('chartreuse'), isNull);
      expect(garmentColorFromName(null), isNull);
    });
  });
}
