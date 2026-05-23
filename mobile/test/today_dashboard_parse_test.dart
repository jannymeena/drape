import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';

/// Parses a representative `GET /today/dashboard` + `GET /usage/current-week`
/// payload (shapes captured live) so a backend field rename is caught here.
void main() {
  final dashboardJson = <String, dynamic>{
    'user': {'name': 'Alex', 'location': 'Toronto', 'timezone': 'America/Toronto'},
    'weather': {
      'temp_c': 14.0,
      'feels_like_c': 12.5,
      'condition': 'Partly cloudy',
      'humidity_pct': 60,
      'wind_kph': 8.0,
    },
    'outfits': [
      {
        'id': 'out-1',
        'user_id': 'u-1',
        'occasion': 'date_night',
        'items': [
          {
            'item_id': 'i-1',
            'name': 'Charcoal blazer',
            'category': 'outerwear',
            'primary_image_url': 'https://x/i1.jpg',
            'is_starter_wardrobe': true,
          },
          {'item_id': 'i-2', 'name': 'White tee', 'category': 'top'},
        ],
        'image_url': null,
        'ai_reasoning_short': 'A grounded date night look.',
        'ai_reasoning_full': 'Full reasoning…',
        'compatibility_score': 92,
        'weather_context': null,
        'using_starter_wardrobe': true,
        'generation_method': 'anthropic_v1',
        'is_logged': false,
        'logged_at': null,
        'worn_count': 0,
        'created_at': '2026-05-23T10:00:00Z',
        'updated_at': '2026-05-23T10:00:00Z',
      },
    ],
    'usage': {
      'outfits_generated_today': 3,
      'outfit_target_per_day': 3,
      'resets_at': '2026-05-24T00:00:00Z',
    },
    'banners': {'starter_wardrobe': true, 'incomplete_profile': true},
  };

  test('TodayDashboard parses user, weather, outfits, usage, banners', () {
    final d = TodayDashboard.fromJson(dashboardJson);
    expect(d.user.name, 'Alex');
    expect(d.user.location, 'Toronto');
    expect(d.weather!.tempC, 14.0);
    expect(d.outfits, hasLength(1));
    expect(d.usage.outfitsGeneratedToday, 3);
    expect(d.banners.starterWardrobe, isTrue);
    expect(d.banners.incompleteProfile, isTrue);
  });

  test('Outfit exposes label, grid urls (with nulls), and the imageless design', () {
    final o = TodayDashboard.fromJson(dashboardJson).outfits.first;
    expect(o.occasion, 'date_night');
    expect(o.occasionLabel, 'Date Night'); // underscore → Title Case
    expect(o.imageUrl, isNull); // composed client-side
    expect(o.compatibilityScore, 92);
    expect(o.items, hasLength(2));
    expect(o.items.first.isStarterWardrobe, isTrue);
    // Second item has no image → null cell preserved for the placeholder grid.
    expect(o.gridImageUrls, ['https://x/i1.jpg', null]);
  });

  test('weather is optional', () {
    final json = Map<String, dynamic>.from(dashboardJson)..['weather'] = null;
    expect(TodayDashboard.fromJson(json).weather, isNull);
  });

  test('CurrentWeekUsage parses counters + tier', () {
    final u = CurrentWeekUsage.fromJson({
      'week_start_date': '2026-05-18',
      'outfits': {'used': 16, 'limit': 21, 'remaining': 5, 'percentage': 76.2},
      'mix_and_match': {'used': 1, 'limit': 10, 'remaining': 9, 'percentage': 10.0},
      'last_reset': null,
      'next_reset': '2026-05-25T00:00:00Z',
      'subscription_tier': 'free',
    });
    expect(u.outfits.used, 16);
    expect(u.outfits.percentage, closeTo(76.2, 1e-9));
    expect(u.isPro, isFalse);
  });
}
