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
    expect(TodayDashboard.fromJson(json).weatherAttribution, isNull);
  });

  test('weather_attribution parses and round-trips (cache fidelity)', () {
    final json = Map<String, dynamic>.from(dashboardJson)
      ..['weather_attribution'] = {
        'service_name': 'Apple Weather',
        'logo_light_url': 'https://x/light.png',
        'logo_dark_url': 'https://x/dark.png',
        'legal_url': 'https://x/legal',
      };
    final parsed = TodayDashboard.fromJson(json);
    final roundTripped = TodayDashboard.fromJson(parsed.toJson());
    for (final d in [parsed, roundTripped]) {
      expect(d.weatherAttribution!.serviceName, 'Apple Weather');
      expect(d.weatherAttribution!.logoLightUrl, 'https://x/light.png');
      expect(d.weatherAttribution!.legalUrl, 'https://x/legal');
    }
    expect(parsed.copyWith(needsStyling: false).weatherAttribution, isNotNull);
  });

  test('TodayLooks parses the styled looks and what is missing', () {
    final looks = TodayLooks.fromJson({
      'outfits': [(dashboardJson['outfits'] as List).first],
      'missing_roles': ['shoes'],
    });
    expect(looks.outfits.single.occasion, 'date_night');
    expect(looks.missingRoles, ['shoes']);
    expect(TodayLooks.fromJson({'outfits': []}).missingRoles, isEmpty);
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

  test('TodayDashboard parses the plan-driven outfit fields', () {
    final json = Map<String, dynamic>.from(dashboardJson)
      ..['wardrobe_ready'] = true
      ..['needs_plan'] = false
      ..['needs_styling'] = true
      ..['wardrobe_mode'] = 'starter'
      ..['missing_roles'] = <String>[]
      ..['day_plans'] = [
        {
          'date': '2026-11-23',
          'plan': {'occasion': 'work_day', 'dress_level': 'business', 'note': null},
          'source': 'day',
          'repeats_weekly': false,
        },
      ];
    final d = TodayDashboard.fromJson(json);
    expect(d.wardrobeReady, isTrue);
    expect(d.needsPlan, isFalse);
    expect(d.needsStyling, isTrue);
    expect(d.wardrobeMode, WardrobeMode.starter);
    expect(d.planKey, 'work_day|business');
  });

  test('outfit fields default when absent; an unplanned day has no key', () {
    final json = Map<String, dynamic>.from(dashboardJson)
      ..['day_plans'] = [
        {'date': '2026-11-23', 'plan': null, 'source': null, 'repeats_weekly': false},
      ];
    final d = TodayDashboard.fromJson(json);
    expect(d.wardrobeReady, isFalse);
    expect(d.needsPlan, isFalse);
    expect(d.needsStyling, isFalse);
    expect(d.wardrobeMode, WardrobeMode.wardrobe);
    expect(d.missingRoles, isEmpty);
    expect(d.planKey, isNull);
  });

  test('toJson round-trips through fromJson (cache fidelity)', () {
    final json = Map<String, dynamic>.from(dashboardJson)
      ..['wardrobe_ready'] = true
      ..['needs_plan'] = true
      ..['needs_styling'] = true
      ..['wardrobe_mode'] = 'starter'
      ..['missing_roles'] = ['shoes']
      ..['day_plans'] = [
        {
          'date': '2026-11-23',
          'plan': {'occasion': 'day_off', 'dress_level': 'casual'},
          'source': 'weekly',
          'repeats_weekly': true,
        },
      ];
    final roundTripped =
        TodayDashboard.fromJson(TodayDashboard.fromJson(json).toJson());
    expect(roundTripped.user.name, 'Alex');
    expect(roundTripped.outfits, hasLength(1));
    expect(roundTripped.outfits.first.occasion, 'date_night');
    expect(roundTripped.outfits.first.compatibilityScore, 92);
    expect(roundTripped.outfits.first.items, hasLength(2));
    expect(roundTripped.weather!.tempC, 14.0);
    expect(roundTripped.usage.outfitsGeneratedToday, 3);
    expect(roundTripped.wardrobeReady, isTrue);
    expect(roundTripped.needsPlan, isTrue);
    expect(roundTripped.needsStyling, isTrue);
    expect(roundTripped.wardrobeMode, WardrobeMode.starter);
    expect(roundTripped.missingRoles, ['shoes']);
    expect(roundTripped.planKey, 'day_off|casual');
  });
}
