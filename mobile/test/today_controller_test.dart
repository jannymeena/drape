import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/log_outfit_result.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/today_controller.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/services/analytics/analytics_service.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';

/// A TodayService whose network calls are replaced with canned results, so the
/// controller's frame + one-call styling logic can be tested without Dio.
class _FakeTodayService extends TodayService {
  _FakeTodayService() : super(Dio());

  TodayDashboard? frame;
  Object? frameError; // thrown by getFrame when set
  CurrentWeekUsage? usage;
  int usageCalls = 0;

  // Styling control: the looks it returns (slot order as given), or a failure.
  List<int> lookSlots = [0];
  List<String> missingRoles = const [];
  bool failStyling = false;
  int styleCalls = 0;

  /// When set, styling waits on it (to hold the call in flight).
  Future<void>? gate;

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
  Future<TodayLooks> styleToday({double? lat, double? lon}) async {
    styleCalls++;
    final call = styleCalls;
    await Future<void>.delayed(Duration.zero); // a real request yields
    if (gate != null) await gate;
    if (failStyling) {
      throw const ApiException(
          code: 'ai_call_failed', message: 'AI failed', statusCode: 502);
    }
    return TodayLooks(
      outfits: [
        for (final slot in lookSlots)
          Outfit.fromJson(_outfitJson('gen$call-$slot', slot: slot)),
      ],
      missingRoles: missingRoles,
    );
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
        {bool logged = false, String occasion = 'casual', int? slot}) =>
    {
      'id': id,
      'occasion': occasion,
      'slot': ?slot,
      'items': <dynamic>[],
      'using_starter_wardrobe': false,
      'is_logged': logged,
      'worn_count': 0,
    };

TodayDashboard _dashboard(
  List<String> ids, {
  bool needsStyling = false,
  bool wardrobeReady = true,
}) =>
    TodayDashboard.fromJson({
      'user': {'name': 'Alex'},
      'outfits': ids.map((id) => _outfitJson(id)).toList(),
      'usage': {'outfits_generated_today': 0},
      'banners': <String, dynamic>{},
      'wardrobe_ready': wardrobeReady,
      'needs_styling': needsStyling,
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
    controller = TodayController(service, cache, DebugAnalyticsService());
  });

  test('loadFrame styles the day in one call; looks land in slot order',
      () async {
    service.frame = _dashboard([], needsStyling: true);
    service.lookSlots = [2, 0, 1];

    await controller.loadFrame();
    expect(controller.state.styling, isTrue); // skeleton while it runs
    await pumpEventQueue();

    final slots = controller.state.dashboard!.outfits.map((o) => o.slot);
    expect(slots, [0, 1, 2]); // cards in slot order
    expect(controller.state.styling, isFalse);
    expect(controller.state.stylingError, isNull);
    expect(controller.state.dashboard!.needsStyling, isFalse);
    expect(service.styleCalls, 1);
    expect(cache.saved!.outfits, hasLength(3)); // persisted for next start
  });

  test('a frame that needs no styling asks for nothing', () async {
    await controller.loadFrame();
    await pumpEventQueue();
    expect(service.styleCalls, 0);
    expect(controller.state.styling, isFalse);
  });

  test('no suitable look: the add-items state with what is missing', () async {
    service.frame = _dashboard([], needsStyling: true);
    service.lookSlots = [];
    service.missingRoles = ['shoes'];

    await controller.loadFrame();
    await pumpEventQueue();

    final dashboard = controller.state.dashboard!;
    expect(dashboard.outfits, isEmpty);
    expect(dashboard.wardrobeReady, isFalse);
    expect(dashboard.missingRoles, ['shoes']);
  });

  test('refreshIfStale skips before the first load and while fresh', () async {
    service.frame = _dashboard([]);
    service.usage = CurrentWeekUsage.fromJson({
      'outfits': {'used': 0, 'limit': 21, 'remaining': 21, 'percentage': 0.0},
      'mix_and_match': {'used': 0, 'limit': 3, 'remaining': 3, 'percentage': 0.0},
      'next_reset': '2026-06-15T05:00:00Z',
      'subscription_tier': 'free',
    });

    await controller.refreshIfStale();
    expect(service.usageCalls, 0); // nothing loaded yet → nothing to refresh

    await controller.loadFrame();
    await controller.refreshIfStale();
    expect(service.usageCalls, 1); // just loaded → still fresh, no reload
  });

  test('a failed styling shows a retry, and retryStyling asks again',
      () async {
    service.frame = _dashboard([], needsStyling: true);
    service.failStyling = true;
    await controller.loadFrame();
    await pumpEventQueue();
    expect(controller.state.styling, isFalse);
    expect(controller.state.stylingError?.code, 'ai_call_failed');

    service.failStyling = false; // it'll succeed now
    await controller.retryStyling();
    await pumpEventQueue();

    expect(controller.state.stylingError, isNull);
    expect(controller.state.dashboard!.outfits.map((o) => o.slot), [0]);
    expect(service.styleCalls, 2);
  });

  test('a reload while styling is in flight does not ask twice', () async {
    service.frame = _dashboard([], needsStyling: true);
    final release = Completer<void>();
    service.gate = release.future;
    await controller.loadFrame();
    await controller.loadFrame(); // pull-to-refresh mid-way
    release.complete();
    await pumpEventQueue();
    expect(service.styleCalls, 1);
    expect(controller.state.dashboard!.outfits, hasLength(1));
  });

  test('planChanged drops styling still running for the old plan', () async {
    service.frame = _dashboard([], needsStyling: true);
    service.lookSlots = [0, 1];
    final release = Completer<void>();
    service.gate = release.future;
    await controller.loadFrame(); // the old plan's styling is in flight
    await pumpEventQueue();
    expect(controller.state.styling, isTrue);

    // The plan changes: the new frame asks for its own looks.
    service.lookSlots = [0];
    final reload = controller.planChanged();
    await pumpEventQueue();
    release.complete();
    await reload;
    await pumpEventQueue();

    // Two calls — the old plan's and the new one's; only the new plan's
    // look lands.
    expect(service.styleCalls, 2);
    expect(controller.state.dashboard!.outfits.map((o) => o.id), ['gen2-0']);
    expect(controller.state.styling, isFalse);
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
