import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayDashboard _dashboard() => TodayDashboard.fromJson({
      'user': {'name': 'Alex', 'location': 'Toronto'},
      'weather': {'temp_c': 14.0, 'feels_like_c': 12.0, 'condition': 'Clear'},
      'outfits': [
        {
          'id': 'o-1',
          'occasion': 'work',
          'items': [
            {'item_id': 'i-1', 'name': 'Tee', 'category': 'tops'},
          ],
          'using_starter_wardrobe': false,
          'is_logged': false,
          'worn_count': 0,
        },
      ],
      'usage': {'outfits_generated_today': 1},
      'banners': {'starter_wardrobe': false, 'incomplete_profile': false},
      'wardrobe_ready': true,
      'pending_occasions': ['casual', 'date_night'],
    });

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save then load round-trips the dashboard', () async {
    final cache = DashboardCache();
    await cache.save(_dashboard());

    final loaded = await cache.load();
    expect(loaded, isNotNull);
    expect(loaded!.user.name, 'Alex');
    expect(loaded.outfits, hasLength(1));
    expect(loaded.outfits.first.occasion, 'work');
    expect(loaded.wardrobeReady, isTrue);
    expect(loaded.pendingOccasions, ['casual', 'date_night']);
  });

  test('load returns null when nothing is cached', () async {
    expect(await DashboardCache().load(), isNull);
  });

  test('load returns null (never throws) on corrupt data', () async {
    SharedPreferences.setMockInitialValues(
        {'today_dashboard_cache_v1': 'not-json{'});
    expect(await DashboardCache().load(), isNull);
  });

  test('clear removes the cached dashboard', () async {
    final cache = DashboardCache();
    await cache.save(_dashboard());
    await cache.clear();
    expect(await cache.load(), isNull);
  });
}
