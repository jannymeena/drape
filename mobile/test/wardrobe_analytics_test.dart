import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_analytics.dart';

/// Parses representative `/wardrobe/analytics/*` payloads (shapes from
/// `app/schemas/analytics.py`).
void main() {
  test('CostPerWearReport parses items + category roll-up', () {
    final r = CostPerWearReport.fromJson({
      'items': [
        {
          'item_id': 'i1',
          'name': 'Oxford Shirt',
          'category': 'tops',
          'purchase_price': 80.0,
          'worn_count': 20,
          'cost_per_wear': 4.0,
        },
      ],
      'categories': [
        {
          'category': 'tops',
          'item_count': 14,
          'total_purchase_price': 560.0,
          'total_wears': 130,
          'average_cost_per_wear': 4.2,
        },
      ],
      'total_items_with_price': 1,
      'total_items_with_wears': 1,
    });

    expect(r.items.single.costPerWear, 4.0);
    expect(r.categories.single.category, 'tops');
    expect(r.categories.single.averageCostPerWear, 4.2);
    expect(r.totalItemsWithPrice, 1);
  });

  test('UtilizationScore parses score + label + window', () {
    final u = UtilizationScore.fromJson({
      'score': 74,
      'items_worn_recently': 12,
      'items_total': 35,
      'days_window': 30,
      'label': 'High',
    });
    expect(u.score, 74);
    expect(u.itemsWornRecently, 12);
    expect(u.label, 'High');
    expect(u.daysWindow, 30);
  });

  test('WeeklyReport parses activity + top items + teaser', () {
    final w = WeeklyReport.fromJson({
      'week_start_date': '2026-04-14',
      'outfits_logged': 12,
      'items_worn_distinct': 8,
      'top_items': [
        {'item_id': 'i1', 'name': 'White Oxford', 'worn_count': 4},
        {'item_id': 'i2', 'name': 'Navy Chinos', 'worn_count': 3},
      ],
      'streak_days': 5,
      'pro_teaser': 'Upgrade to Pro for full reports.',
    });

    expect(w.weekStartDate, DateTime.parse('2026-04-14'));
    expect(w.outfitsLogged, 12);
    expect(w.itemsWornDistinct, 8);
    expect(w.topItems, hasLength(2));
    expect(w.topItems.first.wornCount, 4);
    expect(w.streakDays, 5);
    expect(w.proTeaser, contains('Pro'));
  });

  test('IntelligenceReport parses palette, hidden gems, ratios', () {
    final r = IntelligenceReport.fromJson({
      'total_items': 35,
      'total_wears': 220,
      'average_cost_per_wear': 5.5,
      'color_palette': [
        {'color_name': 'navy', 'item_count': 14, 'worn_count': 80},
        {'color_name': 'white', 'item_count': 10, 'worn_count': 60},
      ],
      'underutilized_items': [
        {
          'item_id': 'u1',
          'name': 'Camel Blazer',
          'category': 'outerwear',
          'worn_count': 1,
          'days_since_last_worn': 92,
        },
        {
          'item_id': 'u2',
          'name': 'Striped Tee',
          'category': 'tops',
          'worn_count': 0,
          'days_since_last_worn': null,
        },
      ],
      'most_worn_category': 'tops',
      'real_vs_starter_ratio': 0.8,
    });

    expect(r.totalItems, 35);
    expect(r.averageCostPerWear, 5.5);
    expect(r.colorPalette, hasLength(2));
    expect(r.colorPalette.first.colorName, 'navy');
    expect(r.underutilizedItems.first.daysSinceLastWorn, 92);
    expect(r.underutilizedItems[1].daysSinceLastWorn, isNull);
    expect(r.mostWornCategory, 'tops');
    expect(r.realVsStarterRatio, 0.8);
  });
}
