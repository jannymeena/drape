import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';

/// Parses representative `GET /wardrobe` + `GET /wardrobe/items/{id}` payloads
/// (shape from `WardrobeItemResponse` / `WardrobeListResponse`) so a backend
/// field rename is caught here, and exercises the display helpers.
void main() {
  Map<String, dynamic> fullItem() => {
        'id': 'item-1',
        'user_id': 'user-1',
        'name': 'Ivory Satin Shirt',
        'category': 'tops',
        'subcategory': 'blouse',
        'images': ['https://img/1.jpg', 'https://img/2.jpg'],
        'primary_image_url': 'https://img/primary.jpg',
        'color_hex': '#FFFFF0',
        'color_name': 'ivory',
        'pattern': 'solid',
        'material': 'silk',
        'formality': 'smart_casual',
        'season': ['spring', 'summer'],
        'brand': 'Aritzia',
        'purchase_price': 120.0,
        'purchase_date': '2024-03-01',
        'description': 'A staple.',
        'worn_count': 8,
        'last_worn': '2026-05-21',
        'cost_per_wear': 15.0,
        'is_favorite': true,
        'favorited_at': '2026-05-01T10:00:00Z',
        'is_starter_wardrobe': false,
        'starter_template_id': null,
        'added_via': 'manual',
        'ai_detection_confidence': null,
        'created_at': '2024-03-01T10:00:00Z',
        'updated_at': '2026-05-21T10:00:00Z',
      };

  test('WardrobeItem parses every field', () {
    final item = WardrobeItem.fromJson(fullItem());

    expect(item.id, 'item-1');
    expect(item.name, 'Ivory Satin Shirt');
    expect(item.category, 'tops');
    expect(item.categoryLabel, 'Tops');
    expect(item.season, ['spring', 'summer']);
    expect(item.purchasePrice, 120.0);
    expect(item.costPerWear, 15.0);
    expect(item.isFavorite, isTrue);
    expect(item.wornCount, 8);
    // primary_image_url wins over the images list.
    expect(item.displayImageUrl, 'https://img/primary.jpg');
    expect(item.addedLabel, 'March 2024');
  });

  test('displayImageUrl falls back to the first image when no primary', () {
    final json = fullItem()..['primary_image_url'] = null;
    final item = WardrobeItem.fromJson(json);
    expect(item.displayImageUrl, 'https://img/1.jpg');
  });

  test('tolerates a minimal item (nulls + missing optionals)', () {
    final item = WardrobeItem.fromJson({
      'id': 'item-2',
      'user_id': 'user-1',
      'name': 'Mystery Tee',
      'category': 'tops',
      'worn_count': 0,
      'is_favorite': false,
      'is_starter_wardrobe': true,
      'added_via': 'starter_seed',
      'created_at': '2026-05-01T10:00:00Z',
      'updated_at': '2026-05-01T10:00:00Z',
    });

    expect(item.displayImageUrl, isNull);
    expect(item.costPerWear, isNull);
    expect(item.lastWornLabel, isNull); // never worn
    expect(item.season, isNull);
    expect(item.isStarterWardrobe, isTrue);
  });

  test('WardrobeListResult parses items + paging', () {
    final result = WardrobeListResult.fromJson({
      'items': [fullItem()],
      'total': 24,
      'limit': 50,
      'offset': 0,
    });

    expect(result.items, hasLength(1));
    expect(result.total, 24);
    expect(result.limit, 50);
  });

  test('category filter maps "all" to a null query and others to literals', () {
    expect(WardrobeCategoryFilter.all.query, isNull);
    expect(WardrobeCategoryFilter.tops.query, 'tops');
    expect(WardrobeCategoryFilter.jewelry.query, 'jewelry');
    // index order is stable (used to map chip taps → filter).
    expect(WardrobeCategoryFilter.values.first, WardrobeCategoryFilter.all);
  });
}
