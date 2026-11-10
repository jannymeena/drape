import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/onboarding_status.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/screens/today_dashboard_screen.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/shop/models/shop.dart';
import 'package:mobile/modules/shop/shop_service.dart';
import 'package:mobile/modules/today/widgets/outfit_card_skeleton.dart';
import 'package:mobile/modules/today/widgets/outfit_carousel.dart';
import 'package:mobile/modules/today/widgets/resume_banner.dart';
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
          'percentage': 0.0,
        },
        'next_reset': '2026-06-15T05:00:00Z',
        'subscription_tier': 'free',
      });

  @override
  Future<Outfit> generateOccasion(
    String occasion, {
    double? lat,
    double? lon,
  }) => _never.future;
}

class _NullCache extends DashboardCache {
  @override
  Future<TodayDashboard?> load() async => null;
  @override
  Future<void> save(TodayDashboard dashboard) async {}
  @override
  Future<void> clear() async {}
}

TodayDashboard _frame(
  List<String> pending, {
  List<String> outfitOccasions = const [],
}) => TodayDashboard.fromJson({
  'user': {'name': 'Alex'},
  'outfits': [
    for (final (i, occasion) in outfitOccasions.indexed)
      {
        'id': 'outfit-$i',
        'occasion': occasion,
        'items': <dynamic>[],
        'ai_reasoning_short': 'Works well.',
      },
  ],
  'usage': {'outfits_generated_today': 0},
  'banners': <String, dynamic>{},
  'wardrobe_ready': true,
  'pending_occasions': pending,
  // What the backend's occasion rulebook sends (a subset is enough here).
  'occasions': [
    for (final (key, label, daily) in const [
      ('work', 'Work', true),
      ('casual', 'Casual', true),
      ('date_night', 'Date Night', true),
      ('gym', 'Gym', false),
    ])
      {'key': key, 'label': label, 'daily': daily},
  ],
});

/// Backend onboarding-status payload driving the resume banner. [next] null
/// means the 7 required measurements are in (nudge hidden).
OnboardingStatus _status({int stepsDone = 0, String? next = 'height'}) =>
    OnboardingStatus(
      onboardingCompleted: true,
      onboardingLastStep: null,
      nextStep: 'completed',
      measurementStepsCompleted: stepsDone,
      nextIncompleteStep: next,
    );

Widget _host(
  TodayService service, {
  OnboardingStatus? status,
  GapAnalysis? gaps,
}) => ProviderScope(
  overrides: [
    // Shop the look stays off the network: no feed, and gaps only when given.
    shopFeedProvider.overrideWith((ref) => Completer<ShopFeed>().future),
    gapAnalysisProvider.overrideWith(
      (ref) async => gaps ?? const GapAnalysis(gaps: [], isTeaser: false),
    ),
    todayServiceProvider.overrideWithValue(service),
    dashboardCacheProvider.overrideWithValue(_NullCache()),
    // Deterministic resume-banner input (default → nothing saved yet).
    onboardingStatusProvider.overrideWith((ref) async => status ?? _status()),
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
  testWidgets('renders the shell + scoped skeletons, no full-screen spinner', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame(['work', 'casual']))));
    await _settle(tester);

    // The old full-screen spinner is gone for good.
    expect(find.text('Curating your outfits…'), findsNothing);
    // Shell chrome rendered immediately.
    expect(find.text("Today's outfits"), findsOneWidget);
    expect(find.text('Today'), findsOneWidget); // app bar title
    // Favourites took the profile avatar's place (Profile is in the nav).
    expect(find.byTooltip('Favourites'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    // Scoped skeletons (one per pending occasion) are shown.
    expect(find.byType(OutfitCardSkeleton), findsWidgets);
  });

  testWidgets('outfits render as a carousel with one featured look', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(_StubService(_frame([], outfitOccasions: ['work', 'casual']))),
    );
    await _settle(tester);

    expect(find.byType(OutfitCarousel), findsOneWidget);
    expect(find.text('Work look'), findsOneWidget);
    expect(find.text('Casual look'), findsOneWidget);
    // The lead look gets the filled CTA, the alternate the tonal one.
    expect(find.text('Wear this'), findsOneWidget);
    expect(find.text('Wear this instead'), findsOneWidget);
    expect(find.text('2 ideas for you'), findsOneWidget);
  });

  testWidgets('pending occasions show a skeleton each in the carousel', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame(['work', 'casual']))));
    await _settle(tester);

    expect(find.byType(OutfitCardSkeleton), findsNWidgets(2));
    expect(find.text('STYLING WORK…'), findsOneWidget);
    expect(find.text('Styling 0 of 2…'), findsOneWidget);
  });

  testWidgets('shows the weekly usage meter for free users', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame([]))));
    await _settle(tester);

    expect(find.text('0 of 21 outfit ideas used this week'), findsOneWidget);
    expect(find.text('Get unlimited'), findsOneWidget);
  });

  testWidgets('shows the next 7 days with today filled', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame([]))));
    await _settle(tester);

    expect(find.text('Your next 7 days'), findsOneWidget);
    expect(find.text('1 of 7 planned'), findsOneWidget);
    expect(find.text('Tomorrow · No plan yet'), findsOneWidget);
  });

  testWidgets('shop the look shows the top wardrobe gap', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame([])),
        gaps: const GapAnalysis(
          gaps: [
            GapItem(
              category: 'outerwear',
              have: 0,
              recommended: 2,
              reason: 'You have 0 outerwear.',
              outfitsUnlocked: 6,
            ),
          ],
          isTeaser: false,
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Shop the look'), findsOneWidget);
    expect(find.text('Fill a gap: outerwear'), findsOneWidget);
    expect(find.text('Zoura may earn a commission when you buy.'), findsOneWidget);
  });

  testWidgets('weather credit sits at the bottom, below the week strip', (
    tester,
  ) async {
    final json = _frame([]).toJson()
      ..['weather'] = {'temp_c': 7.2, 'feels_like_c': 4.1, 'condition': 'rain'}
      ..['weather_attribution'] = {
        'service_name': 'Apple Weather',
        'logo_light_url': 'https://example.test/light.png',
        'logo_dark_url': 'https://example.test/dark.png',
        'legal_url': 'https://example.test/legal',
      };
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(_StubService(TodayDashboard.fromJson(json))),
    );
    await _settle(tester);

    expect(find.text('7°C, feels 4° · Rain'), findsOneWidget);
    final credit = tester.getTopLeft(find.text('Data sources')).dy;
    expect(credit, greaterThan(tester.getTopLeft(find.text('Your next 7 days')).dy));
    expect(credit,
        greaterThan(tester.getTopLeft(find.text('7°C, feels 4° · Rain')).dy));
  });

  testWidgets('no shop section without picks or gaps', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame([]))));
    await _settle(tester);

    expect(find.text('Shop the look'), findsNothing);
  });

  testWidgets('shows the resume banner with 0/8 when nothing is saved', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame([]))));
    await _settle(tester);

    expect(find.byType(ResumeBanner), findsOneWidget);
    expect(find.text('Complete your ZOURA profile'), findsOneWidget);
    expect(find.text('0 of 8 steps done'), findsOneWidget);
  });

  testWidgets('resume banner counts saved steps', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame([])),
        status: _status(stepsDone: 4, next: 'shoulders'),
      ),
    );
    await _settle(tester);

    expect(find.text('4 of 8 steps done'), findsOneWidget);
  });

  testWidgets('resume banner hides when all required measurements exist', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    // A null next step means the 7 required are in — weight (optional)
    // missing must NOT keep the nudge alive (steps_done 7 of 8).
    await tester.pumpWidget(
      _host(
        _StubService(_frame([])),
        status: _status(stepsDone: 7, next: null),
      ),
    );
    await _settle(tester);

    expect(find.byType(ResumeBanner), findsNothing);
  });

  testWidgets(
    'shows the add-items empty state when the wardrobe is not ready',
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
    },
  );
}
