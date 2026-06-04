import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/log_outfit_result.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/today_controller.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/shared/models/api_error.dart';

/// A TodayService whose network calls are replaced with canned results, so the
/// controller's optimistic-update + busy-flag logic can be tested without Dio.
class _FakeTodayService extends TodayService {
  _FakeTodayService() : super(Dio());

  late TodayDashboard dashboard;
  late CurrentWeekUsage usage;
  Outfit? regenResult;
  ApiException? regenError;
  LogOutfitResult? logResult;
  int usageCalls = 0;

  @override
  Future<TodayDashboard> getDashboard({double? lat, double? lon}) async =>
      dashboard;

  @override
  Future<CurrentWeekUsage> getCurrentWeekUsage() async {
    usageCalls++;
    return usage;
  }

  @override
  Future<Outfit> regenerateOutfit(String outfitId) async {
    if (regenError != null) throw regenError!;
    return regenResult!;
  }

  @override
  Future<LogOutfitResult> logOutfitWorn(String outfitId) async {
    return logResult!;
  }
}

Map<String, dynamic> _outfitJson(String id, {bool logged = false}) => {
      'id': id,
      'occasion': 'casual',
      'items': <dynamic>[],
      'using_starter_wardrobe': false,
      'is_logged': logged,
      'worn_count': 0,
    };

TodayDashboard _dashboard(List<String> ids) => TodayDashboard.fromJson({
      'user': {'name': 'Alex'},
      'outfits': ids.map((id) => _outfitJson(id)).toList(),
      'usage': {'outfits_generated_today': 0},
      'banners': <String, dynamic>{},
    });

CurrentWeekUsage _usage() => CurrentWeekUsage.fromJson({
      'outfits': {'used': 5, 'limit': 21, 'remaining': 16, 'percentage': 23.8},
      'mix_and_match': {'used': 0, 'limit': 3, 'remaining': 3, 'percentage': 0.0},
      'next_reset': '2026-05-25T05:00:00Z',
      'subscription_tier': 'free',
    });

void main() {
  late _FakeTodayService service;
  late TodayController controller;

  setUp(() {
    service = _FakeTodayService()
      ..dashboard = _dashboard(['a', 'b'])
      ..usage = _usage();
    controller = TodayController(service);
  });

  test('regenerate swaps the fresh outfit into the old card slot', () async {
    await controller.load();
    service.regenResult =
        Outfit.fromJson(_outfitJson('c')); // new id, replaces 'a'

    await controller.regenerate('a');

    final ids = controller.state.dashboard!.outfits.map((o) => o.id).toList();
    expect(ids, ['c', 'b']); // position preserved, id swapped
    expect(controller.state.regeneratingIds, isEmpty); // spinner cleared
    expect(service.usageCalls, greaterThan(1)); // banner refreshed post-regen
  });

  test('regenerate rethrows a 429 and clears the busy flag', () async {
    await controller.load();
    service.regenError = const ApiException(
      code: 'limit_reached',
      message: 'Weekly outfits limit reached (21/21).',
      statusCode: 429,
    );

    await expectLater(
      controller.regenerate('a'),
      throwsA(isA<ApiException>()
          .having((e) => e.statusCode, 'statusCode', 429)
          .having((e) => e.code, 'code', 'limit_reached')),
    );
    expect(controller.state.regeneratingIds, isEmpty);
    // The outfit list is untouched on failure.
    expect(controller.state.dashboard!.outfits.map((o) => o.id), ['a', 'b']);
  });

  test('logWorn marks the outfit logged and returns the toast', () async {
    await controller.load();
    service.logResult = LogOutfitResult.fromJson({
      'outfit_id': 'a',
      'logged_at': '2026-05-23T10:00:00Z',
      'current_streak': 3,
      'longest_streak': 3,
      'total_outfits_logged': 7,
      'toast': {
        'type': 'default',
        'message': 'Outfit logged!',
        'duration_ms': 2000,
        'background': '#6B4530',
        'haptic': 'light',
      },
    });

    final result = await controller.logWorn('a');

    expect(result.toast.message, 'Outfit logged!');
    final logged = controller.state.dashboard!.outfits.firstWhere((o) => o.id == 'a');
    expect(logged.isLogged, isTrue);
    expect(logged.wornCount, 1);
    expect(controller.state.loggingIds, isEmpty);
  });
}
