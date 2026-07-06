import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/log_outfit_result.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/today_controller.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';

/// A TodayService whose network calls are replaced with canned results, so the
/// controller's frame + per-occasion fan-out logic can be tested without Dio.
class _FakeTodayService extends TodayService {
  _FakeTodayService() : super(Dio());

  TodayDashboard? frame;
  Object? frameError; // thrown by getFrame when set
  CurrentWeekUsage? usage;
  int usageCalls = 0;

  // Per-occasion generation control.
  final Map<String, Outfit> occasionResults = {};
  final Set<String> failOccasions = {};
  int generateCalls = 0;

  Outfit? regenResult;
  ApiException? regenError;
  LogOutfitResult? logResult;

  @override
  Future<TodayDashboard> getFrame({double? lat, double? lon}) async {
    if (frameError != null) throw frameError!;
    return frame!;
  }

  @override
  Future<CurrentWeekUsage> getCurrentWeekUsage() async {
    usageCalls++;
    return usage!;
  }

  @override
  Future<Outfit> generateOccasion(String occasion,
      {double? lat, double? lon}) async {
    generateCalls++;
    if (failOccasions.contains(occasion)) {
      throw const ApiException(
          code: 'ai_call_failed', message: 'AI failed', statusCode: 502);
    }
    return occasionResults[occasion] ??
        Outfit.fromJson(_outfitJson('gen-$occasion', occasion: occasion));
  }

  @override
  Future<Outfit> regenerateOutfit(String outfitId) async {
    if (regenError != null) throw regenError!;
    return regenResult!;
  }

  @override
  Future<LogOutfitResult> logOutfitWorn(String outfitId) async => logResult!;
}

/// In-memory stand-in for the shared_preferences-backed cache.
class _FakeDashboardCache extends DashboardCache {
  TodayDashboard? saved;

  @override
  Future<TodayDashboard?> load() async => saved;

  @override
  Future<void> save(TodayDashboard dashboard) async => saved = dashboard;

  @override
  Future<void> clear() async => saved = null;
}

Map<String, dynamic> _outfitJson(String id,
        {bool logged = false, String occasion = 'casual'}) =>
    {
      'id': id,
      'occasion': occasion,
      'items': <dynamic>[],
      'using_starter_wardrobe': false,
      'is_logged': logged,
      'worn_count': 0,
    };

TodayDashboard _dashboard(
  List<String> ids, {
  List<String> pending = const [],
  bool wardrobeReady = true,
}) =>
    TodayDashboard.fromJson({
      'user': {'name': 'Alex'},
      'outfits': ids.map((id) => _outfitJson(id)).toList(),
      'usage': {'outfits_generated_today': 0},
      'banners': <String, dynamic>{},
      'wardrobe_ready': wardrobeReady,
      'pending_occasions': pending,
    });

CurrentWeekUsage _usage() => CurrentWeekUsage.fromJson({
      'outfits': {'used': 5, 'limit': 21, 'remaining': 16, 'percentage': 23.8},
      'mix_and_match': {'used': 0, 'limit': 3, 'remaining': 3, 'percentage': 0.0},
      'next_reset': '2026-05-25T05:00:00Z',
      'subscription_tier': 'free',
    });

void main() {
  late _FakeTodayService service;
  late _FakeDashboardCache cache;
  late TodayController controller;

  setUp(() {
    cache = _FakeDashboardCache();
    service = _FakeTodayService()
      ..frame = _dashboard(['a', 'b'])
      ..usage = _usage();
    controller = TodayController(service, cache);
  });

  test('loadFrame seeds pending and fills each occasion in parallel', () async {
    service.frame = _dashboard([], pending: ['work', 'casual']);

    await controller.loadFrame();
    await pumpEventQueue();

    final occasions =
        controller.state.dashboard!.outfits.map((o) => o.occasion).toSet();
    expect(occasions, {'work', 'casual'});
    expect(controller.state.pendingOccasions, isEmpty);
    expect(controller.state.failedOccasions, isEmpty);
    expect(service.generateCalls, 2);
  });

  test('a failed occasion is isolated; the others still fill', () async {
    service.frame = _dashboard([], pending: ['work', 'casual']);
    service.failOccasions.add('casual');

    await controller.loadFrame();
    await pumpEventQueue();

    final occasions =
        controller.state.dashboard!.outfits.map((o) => o.occasion).toList();
    expect(occasions, ['work']);
    expect(controller.state.failedOccasions.keys, contains('casual'));
    expect(controller.state.pendingOccasions, isEmpty);
  });

  test('generateOccasion re-generates a previously failed occasion', () async {
    service.frame = _dashboard([], pending: ['casual']);
    service.failOccasions.add('casual');
    await controller.loadFrame();
    await pumpEventQueue();
    expect(controller.state.failedOccasions.keys, contains('casual'));

    service.failOccasions.remove('casual'); // it'll succeed now
    await controller.generateOccasion('casual');
    await pumpEventQueue();

    expect(controller.state.failedOccasions, isEmpty);
    expect(controller.state.dashboard!.outfits.map((o) => o.occasion),
        contains('casual'));
  });

  test('generateOccasion styles an occasion the frame never scheduled',
      () async {
    service.frame = _dashboard([], pending: []);
    await controller.loadFrame();
    await pumpEventQueue();
    expect(controller.state.dashboard!.outfits, isEmpty);

    await controller.generateOccasion('gym');
    await pumpEventQueue();

    expect(controller.state.dashboard!.outfits.map((o) => o.occasion),
        contains('gym'));
    expect(controller.state.pendingOccasions, isEmpty);
  });

  test('a non-ApiException from getFrame never sticks the spinner', () async {
    // Freeze-bug regression: anything but an ApiException must still clear
    // frameLoading and surface a frameError — not hang on the loading state.
    service.frame = null;
    service.frameError = Exception('boom');

    await controller.loadFrame();

    expect(controller.state.frameLoading, isFalse);
    expect(controller.state.frameError, isNotNull);
  });

  test('regenerate swaps the fresh outfit into the old card slot', () async {
    await controller.loadFrame();
    service.regenResult =
        Outfit.fromJson(_outfitJson('c')); // new id, replaces 'a'

    await controller.regenerate('a');

    final ids = controller.state.dashboard!.outfits.map((o) => o.id).toList();
    expect(ids, ['c', 'b']); // position preserved, id swapped
    expect(controller.state.regeneratingIds, isEmpty); // spinner cleared
    expect(service.usageCalls, greaterThan(1)); // banner refreshed post-regen
  });

  test('regenerate rethrows a 429 and clears the busy flag', () async {
    await controller.loadFrame();
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
    await controller.loadFrame();
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
    final logged =
        controller.state.dashboard!.outfits.firstWhere((o) => o.id == 'a');
    expect(logged.isLogged, isTrue);
    expect(logged.wornCount, 1);
    expect(controller.state.loggingIds, isEmpty);
  });
}
