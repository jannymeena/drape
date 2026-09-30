import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/modules/onboarding/models/starter_wardrobe.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/onboarding/screens/wardrobe_setup_screen.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/screens/today_dashboard_screen.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';
import 'package:mobile/shared/providers/network_provider.dart';
import 'package:mobile/shared/services/session_store.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';

/// Server-side wardrobe: starter items appear once the kit is assigned.
class _Backend {
  bool starterAssigned = false;
}

class _StubOnboarding extends OnboardingService {
  _StubOnboarding(this.backend) : super(Dio());
  final _Backend backend;

  @override
  Future<StarterWardrobeResult> assignStarterWardrobe() async {
    backend.starterAssigned = true;
    return const StarterWardrobeResult(
      templateId: 'capsule',
      itemsMaterialized: 12,
      swapped: false,
      starterItemsCount: 12,
    );
  }
}

class _StubWardrobe extends WardrobeService {
  _StubWardrobe(this.backend) : super(Dio());
  final _Backend backend;

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    // Real items: none. Visible (real + starter): the kit once assigned.
    final total = isStarter == false || !backend.starterAssigned ? 0 : 12;
    return WardrobeListResult(
        items: const [], total: total, limit: limit, offset: offset);
  }
}

/// The screen prefetches Today after assigning; keep that off the network.
class _StubToday extends TodayService {
  _StubToday() : super(Dio());

  @override
  Future<TodayDashboard> getFrame({double? lat, double? lon}) async =>
      TodayDashboard.fromJson({
        'user': {'name': 'Alex'},
        'outfits': <dynamic>[],
        'usage': {'outfits_generated_today': 0},
        'banners': <String, dynamic>{},
        'wardrobe_ready': true,
        'pending_occasions': <String>[],
      });

  @override
  Future<CurrentWeekUsage> getCurrentWeekUsage() async =>
      CurrentWeekUsage.fromJson({
        'outfits': {'used': 0, 'limit': 21, 'remaining': 21, 'percentage': 0.0},
        'mix_and_match': {
          'used': 0,
          'limit': 3,
          'remaining': 3,
          'percentage': 0.0
        },
        'next_reset': '2026-06-15T05:00:00Z',
        'subscription_tier': 'free',
      });

  @override
  Future<Outfit> generateOccasion(String occasion,
          {double? lat, double? lon}) =>
      Completer<Outfit>().future;
}

class _NullCache extends DashboardCache {
  @override
  Future<TodayDashboard?> load() async => null;
  @override
  Future<void> save(TodayDashboard dashboard) async {}
  @override
  Future<void> clear() async {}
}

/// Pumps wardrobe setup (the last registration step) with Today as the only
/// other route — so navigating anywhere else, like the parked avatar steps,
/// would fail the test.
Future<ProviderContainer> _pumpSetup(WidgetTester tester, _Backend backend) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  final container = ProviderContainer(overrides: [
    onboardingServiceProvider.overrideWithValue(_StubOnboarding(backend)),
    wardrobeServiceProvider.overrideWithValue(_StubWardrobe(backend)),
    todayServiceProvider.overrideWithValue(_StubToday()),
    dashboardCacheProvider.overrideWithValue(_NullCache()),
  ]);
  addTearDown(container.dispose);

  final router = GoRouter(
    initialLocation: WardrobeSetupScreen.path,
    routes: [
      GoRoute(
        path: WardrobeSetupScreen.path,
        name: WardrobeSetupScreen.name,
        builder: (_, _) => const WardrobeSetupScreen(),
      ),
      GoRoute(
        path: TodayDashboardScreen.path,
        name: TodayDashboardScreen.name,
        builder: (_, _) => const Scaffold(body: Text('today')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return container;
}

Future<void> _startWithStarterWardrobe(WidgetTester tester) async {
  final button = find.text('START WITH A STARTER WARDROBE');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  testWidgets(
      'assigning the starter wardrobe refreshes the counts behind the '
      '"unlock real wardrobe mode" card', (tester) async {
    final container = await _pumpSetup(tester, _Backend());

    // The setup screen cached the pre-assignment counts: no starter items.
    expect(container.read(wardrobeCapacityProvider).value?.activeStarterItems, 0);

    await _startWithStarterWardrobe(tester);

    final capacity = await container.read(wardrobeCapacityProvider.future);
    expect(capacity.activeStarterItems, 12);

    // Let the Today prefetch's device-location budget (3 s) run out.
    await tester.pump(const Duration(seconds: 4));
  });

  testWidgets('registration ends on Today, skipping the parked avatar steps',
      (tester) async {
    await _pumpSetup(tester, _Backend());

    await _startWithStarterWardrobe(tester);
    await tester.pump(const Duration(seconds: 4)); // location budget
    await tester.pumpAndSettle();

    expect(find.text('today'), findsOneWidget);
    expect(SessionStore.state.value, isTrue);
  });
}
