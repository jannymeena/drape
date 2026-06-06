import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/screens/today_dashboard_screen.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/today/widgets/outfit_card_skeleton.dart';
import 'package:mobile/shared/providers/network_provider.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';

/// Returns the frame, then never completes per-occasion generation so the
/// skeletons stay on screen for the assertions.
class _StubService extends TodayService {
  _StubService(this.frame) : super(Dio());
  final TodayDashboard frame;
  final Completer<Outfit> _never = Completer<Outfit>();

  @override
  Future<TodayDashboard> getFrame({double? lat, double? lon}) async => frame;

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
      _never.future;
}

class _NullCache extends DashboardCache {
  @override
  Future<TodayDashboard?> load() async => null;
  @override
  Future<void> save(TodayDashboard dashboard) async {}
  @override
  Future<void> clear() async {}
}

TodayDashboard _frame(List<String> pending) => TodayDashboard.fromJson({
      'user': {'name': 'Alex'},
      'outfits': <dynamic>[],
      'usage': {'outfits_generated_today': 0},
      'banners': <String, dynamic>{},
      'wardrobe_ready': true,
      'pending_occasions': pending,
    });

Widget _host(TodayService service) => ProviderScope(
      overrides: [
        todayServiceProvider.overrideWithValue(service),
        dashboardCacheProvider.overrideWithValue(_NullCache()),
      ],
      child: const MaterialApp(home: TodayDashboardScreen()),
    );

/// Pumps several frames so the async `loadFrame` chain (cache → coords → frame)
/// settles. Avoids `pumpAndSettle` because the shimmer animation never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// A tall surface so the lazy sliver builds the skeleton cards we assert on.
void _tallSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Stubs the geolocator method channel so `currentDeviceCoords()` resolves to
/// null immediately (location services "off") instead of hanging on a platform
/// channel the test harness never answers.
void _stubGeolocator(WidgetTester tester) {
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter.baseflow.com/geolocator'),
    (call) async => false,
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter.baseflow.com/geolocator'),
      null,
    );
  });
}

void main() {
  testWidgets('renders the shell + scoped skeletons, no full-screen spinner',
      (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame(['work', 'casual']))));
    await _settle(tester);

    // The old full-screen spinner is gone for good.
    expect(find.text('Curating your outfits…'), findsNothing);
    // Shell chrome rendered immediately.
    expect(find.text("Today's Picks"), findsOneWidget);
    // Scoped skeletons (one per pending occasion) are shown.
    expect(find.byType(OutfitCardSkeleton), findsWidgets);
  });

  testWidgets('shows the add-items empty state when the wardrobe is not ready',
      (tester) async {
    final notReady = TodayDashboard.fromJson({
      'user': {'name': 'Alex'},
      'outfits': <dynamic>[],
      'usage': {'outfits_generated_today': 0},
      'banners': <String, dynamic>{},
      'wardrobe_ready': false,
      'pending_occasions': <dynamic>[],
    });
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(notReady)));
    await _settle(tester);

    expect(find.byType(OutfitCardSkeleton), findsNothing);
    expect(
      find.text('Add a few wardrobe items to start getting daily outfits.'),
      findsOneWidget,
    );
  });
}
