import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';
import 'package:mobile/shared/services/storage_service.dart';
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
      'needs_styling': true,
    });

DashboardCache _cache({DateTime? now}) => DashboardCache(
      storage: StorageService(),
      now: now == null ? null : () => now,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({'user_id': 'u1'});
  });

  test('save then load round-trips the dashboard', () async {
    final cache = _cache();
    await cache.save(_dashboard());

    final loaded = await cache.load();
    expect(loaded, isNotNull);
    expect(loaded!.user.name, 'Alex');
    expect(loaded.outfits, hasLength(1));
    expect(loaded.outfits.first.occasion, 'work');
    expect(loaded.wardrobeReady, isTrue);
    expect(loaded.needsStyling, isTrue);
  });

  test('load returns null when nothing is cached', () async {
    expect(await _cache().load(), isNull);
  });

  test('load returns null (never throws) on corrupt data', () async {
    SharedPreferences.setMockInitialValues(
        {'today_dashboard_cache_v2': 'not-json{'});
    expect(await _cache().load(), isNull);
  });

  test('clear removes the cached dashboard', () async {
    final cache = _cache();
    await cache.save(_dashboard());
    await cache.clear();
    expect(await cache.load(), isNull);
  });

  test("another account never sees the cached frame", () async {
    await _cache().save(_dashboard());

    // u1 is signed out without a clear (e.g. a failed refresh); u2 signs in.
    FlutterSecureStorage.setMockInitialValues({'user_id': 'u2'});
    expect(await _cache().load(), isNull);
  });

  test('nothing is cached or loaded without a signed-in user', () async {
    FlutterSecureStorage.setMockInitialValues({});
    final cache = _cache();
    await cache.save(_dashboard());
    expect(await cache.load(), isNull);
  });

  test("yesterday's frame is a miss", () async {
    await _cache(now: DateTime(2026, 11, 22, 23, 50)).save(_dashboard());
    expect(await _cache(now: DateTime(2026, 11, 22, 8)).load(), isNotNull);
    expect(await _cache(now: DateTime(2026, 11, 23, 0, 5)).load(), isNull);
  });

  test('a legacy v1 entry (no owner) is ignored and cleared', () async {
    SharedPreferences.setMockInitialValues({
      'today_dashboard_cache_v1': '{"user": {"name": "Old"}, "outfits": []}',
    });
    final cache = _cache();
    expect(await cache.load(), isNull);
    await cache.clear();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('today_dashboard_cache_v1'), isNull);
  });
}
