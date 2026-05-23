import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_mutations.dart';

void main() {
  group('WardrobeItemInput.toJson', () {
    test('omits null fields, maps snake_case, formats the date', () {
      final json = const WardrobeItemInput(
        name: 'Linen Shirt',
        category: 'tops',
        colorName: 'white',
        colorHex: '#F6F2EC',
        formality: 'smart_casual',
        season: ['spring', 'summer'],
      ).copyWithDate(DateTime(2024, 3, 5)).toJson();

      expect(json['name'], 'Linen Shirt');
      expect(json['category'], 'tops');
      expect(json['color_name'], 'white');
      expect(json['color_hex'], '#F6F2EC');
      expect(json['formality'], 'smart_casual');
      expect(json['season'], ['spring', 'summer']);
      expect(json['purchase_date'], '2024-03-05'); // zero-padded
      // Untouched optionals are absent (so PATCH leaves them alone).
      expect(json.containsKey('material'), isFalse);
      expect(json.containsKey('brand'), isFalse);
      expect(json.containsKey('description'), isFalse);
    });

    test('a partial (patch-style) input only serializes what is set', () {
      final json = const WardrobeItemInput(name: 'Renamed').toJson();
      expect(json, {'name': 'Renamed'});
    });
  });

  test('LogWornResult parses counters + already-logged flag', () {
    final r = LogWornResult.fromJson({
      'item_id': 'i1',
      'worn_count': 3,
      'last_worn': '2026-05-23',
      'cost_per_wear': 12.5,
      'already_logged_today': true,
    });
    expect(r.itemId, 'i1');
    expect(r.wornCount, 3);
    expect(r.lastWorn, DateTime.parse('2026-05-23'));
    expect(r.costPerWear, 12.5);
    expect(r.alreadyLoggedToday, isTrue);
  });

  test('ToggleFavoriteResult parses state + nullable timestamp', () {
    final on = ToggleFavoriteResult.fromJson({
      'item_id': 'i1',
      'is_favorite': true,
      'favorited_at': '2026-05-23T10:00:00Z',
    });
    expect(on.isFavorite, isTrue);
    expect(on.favoritedAt, isNotNull);

    final off = ToggleFavoriteResult.fromJson(
        {'item_id': 'i1', 'is_favorite': false, 'favorited_at': null});
    expect(off.isFavorite, isFalse);
    expect(off.favoritedAt, isNull);
  });

  group('WardrobeCapacity', () {
    test('level + banner visibility track the thresholds', () {
      expect(const WardrobeCapacity(used: 10, isPro: false).shouldShowBanner,
          isFalse); // below soft
      expect(const WardrobeCapacity(used: 22, isPro: false).level, 'soft');
      expect(const WardrobeCapacity(used: 27, isPro: false).level, 'urgent');
      expect(const WardrobeCapacity(used: 30, isPro: false).level, 'blocked');
      expect(const WardrobeCapacity(used: 30, isPro: false).remaining, 0);
    });

    test('Pro never shows the banner', () {
      expect(const WardrobeCapacity(used: 30, isPro: true).shouldShowBanner,
          isFalse);
    });
  });
}

/// Test-only helper to set `purchaseDate` without retyping every field.
extension on WardrobeItemInput {
  WardrobeItemInput copyWithDate(DateTime date) => WardrobeItemInput(
        name: name,
        category: category,
        colorName: colorName,
        colorHex: colorHex,
        formality: formality,
        season: season,
        purchaseDate: date,
      );
}
