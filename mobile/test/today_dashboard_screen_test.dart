import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/onboarding_status.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/notifications/models/app_notification.dart';
import 'package:mobile/modules/notifications/notifications_controller.dart';
import 'package:mobile/modules/today/day_plans_service.dart';
import 'package:mobile/modules/today/models/day_plan.dart';
import 'package:mobile/modules/today/models/today_dashboard.dart';
import 'package:mobile/modules/today/models/usage.dart';
import 'package:mobile/modules/today/screens/today_dashboard_screen.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/shop/models/shop.dart';
import 'package:mobile/modules/shop/shop_service.dart';
import 'package:mobile/modules/today/widgets/outfit_card_skeleton.dart';
import 'package:mobile/modules/today/widgets/outfit_carousel.dart';
import 'package:mobile/modules/today/widgets/outfit_collage.dart';
import 'package:mobile/modules/today/widgets/outfit_garment_grid.dart';
import 'package:mobile/modules/today/widgets/plan_day_sheet.dart';
import 'package:mobile/modules/today/widgets/plan_today_card.dart';
import 'package:mobile/modules/today/widgets/resume_banner.dart';
import 'package:mobile/modules/today/widgets/starter_wardrobe_banner.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_mutations.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/providers/network_provider.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';

import 'support/fake_day_plans_service.dart';

/// Returns the frame, then never completes per-slot generation so the
/// skeletons stay on screen for the assertions.
class _StubService extends TodayService {
  _StubService(this.frame, {this.shop}) : super(Dio());
  final TodayDashboard frame;
  final TodayShop? shop;

  @override
  Future<TodayShop> getShop({double? lat, double? lon}) async =>
      shop ?? (throw const ApiException(code: 'offline', message: 'offline'));
  final Completer<TodayLooks> _never = Completer<TodayLooks>();

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
  Future<TodayLooks> styleToday({double? lat, double? lon}) => _never.future;
}

class _NullCache extends DashboardCache {
  @override
  Future<TodayDashboard?> load() async => null;
  @override
  Future<void> save(TodayDashboard dashboard) async {}
  @override
  Future<void> clear() async {}
}

TodayDashboard _frame({
  bool needsStyling = false,
  String wardrobeMode = 'wardrobe',
  List<String> outfitOccasions = const [],
  List<Map<String, dynamic>> items = const [],
  bool wardrobeReady = true,
  bool needsPlan = false,
  List<String> missingRoles = const [],
  DayPlan? plan,
}) => TodayDashboard.fromJson({
  'user': {'name': 'Alex'},
  'outfits': [
    for (final (i, occasion) in outfitOccasions.indexed)
      {
        'id': 'outfit-$i',
        'occasion': occasion,
        'slot': i,
        'items': items,
        'ai_reasoning_short': 'Works well.',
      },
  ],
  'usage': {'outfits_generated_today': 0},
  'banners': <String, dynamic>{},
  'wardrobe_ready': wardrobeReady,
  'needs_plan': needsPlan,
  'needs_styling': needsStyling,
  'wardrobe_mode': wardrobeMode,
  'missing_roles': missingRoles,
  // The plan the frame was styled for, as the backend sends it.
  'day_plans': [
    {
      'date': '2026-11-23',
      'plan': plan == null
          ? null
          : {'occasion': plan.occasion.wire, 'dress_level': plan.dress.wire},
    },
  ],
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

/// One outfit piece as the backend sends it.
Map<String, dynamic> _piece(
  String name,
  String category, {
  int priority = 500,
  Map<String, Object?> extra = const {},
}) => {
  'item_id': 'item-$name',
  'name': name,
  'category': category,
  'primary_image_url': null,
  'dress_priority': priority,
  ...extra,
};

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
  List<DayPlan> plans = const [],
  List<AppNotification> notifications = const [],
  WardrobeCapacity? capacity,
}) => ProviderScope(
  overrides: [
    if (capacity != null)
      wardrobeCapacityProvider.overrideWith((ref) async => capacity),
    notificationsProvider.overrideWith(
      (ref) => NotificationsController(notifications),
    ),
    dayPlansServiceProvider.overrideWithValue(
      FakeDayPlansService(plans: plans),
    ),
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
  group('week strip', () {
    Finder needsPlan() => find.bySemanticsLabel(RegExp(r', needs a plan$'));
    Finder planned() => find.bySemanticsLabel(RegExp(r', planned$'));

    testWidgets('today with no plan is dashed like the other days', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(_host(_StubService(_frame())));
      await _settle(tester);
      expect(needsPlan(), findsNWidgets(7));
      expect(planned(), findsNothing);
    });

    testWidgets("today's plan fills its marker", (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(_frame()),
          plans: [
            DayPlan(
              date: appToday(),
              occasion: DayOccasion.workDay,
              dress: DressLevel.smartCasual,
            ),
          ],
        ),
      );
      await _settle(tester);
      expect(planned(), findsOneWidget);
      expect(needsPlan(), findsNWidgets(6));
      expect(find.byIcon(DayOccasion.workDay.icon), findsWidgets);
    });
  });

  group('outfits from the day\'s plan', () {
    DayPlan workDay() => DayPlan(
      date: appToday(),
      occasion: DayOccasion.workDay,
      dress: DressLevel.smartCasual,
    );

    testWidgets('no plan for today: the card asks what\'s on', (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(_host(_StubService(_frame(needsPlan: true))));
      await _settle(tester);

      expect(find.byType(PlanTodayCard), findsOneWidget);
      expect(find.text("What's on today?"), findsOneWidget);
      expect(find.text('Plan today'), findsOneWidget);
      // No skeleton cards — just the plan card's hidden sizing one.
      expect(
        find.descendant(
          of: find.byType(PlanTodayCard),
          matching: find.byType(OutfitCardSkeleton),
        ),
        findsOneWidget,
      );
      expect(find.byType(OutfitCardSkeleton), findsOneWidget);
    });

    testWidgets('the plan card is an outfit card\'s height', (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(_host(_StubService(_frame(needsPlan: true))));
      await _settle(tester);
      final planCard = tester.getSize(find.byType(PlanTodayCard)).height;

      await tester.pumpWidget(
        _host(_StubService(_frame(needsStyling: true, plan: workDay())), plans: [workDay()]),
      );
      await _settle(tester);
      final skeleton = tester.getSize(find.byType(OutfitCardSkeleton)).height;
      expect(planCard, closeTo(skeleton, 0.5));
    });

    testWidgets('tapping the plan card opens Plan the day', (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(_host(_StubService(_frame(needsPlan: true))));
      await _settle(tester);

      await tester.tap(find.byType(PlanTodayCard));
      await _settle(tester);
      expect(find.byType(PlanDaySheet), findsOneWidget);
    });

    testWidgets('own-wardrobe looks: no starter-wardrobe banner', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(_frame()),
          capacity: const WardrobeCapacity(
            used: 2,
            isPro: false,
            visibleTotal: 14,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(StarterWardrobeBanner), findsNothing);
    });

    testWidgets('starter mode: the banner counts toward real wardrobe mode', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(_frame(wardrobeMode: 'starter')),
          capacity: const WardrobeCapacity(
            used: 2,
            isPro: false,
            visibleTotal: 14,
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(StarterWardrobeBanner), findsOneWidget);
      expect(find.text('2/10 ITEMS TO UNLOCK REAL WARDROBE MODE'), findsOneWidget);
    });

    testWidgets('a look of cut-outs lies as a flat-lay', (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      final cutout = {
        'cutout_url': 'https://img.example/c.png',
        'cutout_box': [0.1, 0.1, 0.8, 0.8],
      };
      await tester.pumpWidget(
        _host(
          _StubService(
            _frame(
              outfitOccasions: ['work'],
              items: [
                _piece('Shirt', 'tops', extra: cutout),
                _piece('Trousers', 'bottoms', extra: cutout),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(OutfitCollage), findsOneWidget);
      expect(find.byType(OutfitGarmentGrid), findsNothing);
    });

    testWidgets('pieces not cut out yet show as a garment grid', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(
            _frame(
              outfitOccasions: ['work'],
              items: [
                _piece('Loafers', 'shoes'),
                _piece('Camel Blazer', 'outerwear', priority: 900),
                _piece('Trousers', 'bottoms'),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(OutfitGarmentGrid), findsOneWidget);
      expect(find.byType(OutfitCollage), findsNothing);
      // The lead tile is the piece that leads the look, named.
      expect(find.text('CAMEL BLAZER'), findsOneWidget);
    });

    testWidgets('a starter look shows as a grid with buy pills', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      const shop = {'product_url': 'https://shop.example/p'};
      await tester.pumpWidget(
        _host(
          _StubService(
            _frame(
              wardrobeMode: 'starter',
              outfitOccasions: ['casual'],
              items: [
                _piece('Tee', 'tops', extra: shop),
                _piece('Jeans', 'bottoms', extra: shop),
              ],
            ),
          ),
        ),
      );
      await _settle(tester);
      expect(find.byType(OutfitGarmentGrid), findsOneWidget);
      expect(find.text('BUY'), findsNWidgets(2));
    });

    testWidgets('no complete look: the empty state names what to add', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(
            _frame(wardrobeReady: false, missingRoles: ['bottom', 'shoes']),
          ),
        ),
      );
      await _settle(tester);
      expect(
        find.text(
          'Add a bottom and shoes to your wardrobe to complete a look for today.',
        ),
        findsOneWidget,
      );
      expect(find.byType(OutfitCarousel), findsNothing);
    });

    testWidgets('nothing to say what\'s missing: the generic empty state', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(_StubService(_frame(wardrobeReady: false))),
      );
      await _settle(tester);
      expect(
        find.text('Add a few wardrobe items to start getting daily outfits.'),
        findsOneWidget,
      );
    });

    testWidgets('more than one look: page dots under the carousel', (
      tester,
    ) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(
          _StubService(_frame(outfitOccasions: ['work', 'work', 'work'])),
        ),
      );
      await _settle(tester);
      expect(find.bySemanticsLabel('Look 1 of 3'), findsOneWidget);
    });

    testWidgets('a single look: no dots', (tester) async {
      _tallSurface(tester);
      _stubGeolocator(tester);
      await tester.pumpWidget(
        _host(_StubService(_frame(outfitOccasions: ['work']))),
      );
      await _settle(tester);
      expect(find.bySemanticsLabel(RegExp(r'^Look \d of \d$')), findsNothing);
    });
  });

  testWidgets('renders the shell + scoped skeletons, no full-screen spinner', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame(needsStyling: true))));
    await _settle(tester);

    // The old full-screen spinner is gone for good.
    expect(find.text('Curating your outfits…'), findsNothing);
    // Shell chrome rendered immediately.
    // No "Today's outfits" header, idea count or "My outfits" link.
    expect(find.text("Today's outfits"), findsNothing);
    expect(find.text('My outfits'), findsNothing);
    expect(find.text('Today'), findsOneWidget); // app bar title
    // Favourites took the profile avatar's place (Profile is in the nav).
    expect(find.byTooltip('Favourites'), findsOneWidget);
    expect(find.byTooltip('Notifications'), findsOneWidget);
    // A scoped skeleton shows while the day's looks are styled.
    expect(find.byType(OutfitCardSkeleton), findsWidgets);
  });

  testWidgets('outfits render as a carousel with one featured look', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(_StubService(_frame(outfitOccasions: ['work', 'casual']))),
    );
    await _settle(tester);

    expect(find.byType(OutfitCarousel), findsOneWidget);
    expect(find.text('Work look'), findsOneWidget);
    expect(find.text('Casual look'), findsOneWidget);
    // The lead look gets the filled CTA, the alternate the tonal one.
    expect(find.text('Wear this'), findsOneWidget);
    expect(find.text('Wear this instead'), findsOneWidget);
    expect(find.textContaining('ideas for you'), findsNothing);
    // Card titles use the greeting's face (Newsreader 24, semibold, tight).
    final title = tester.widget<Text>(find.text('Work look')).style!;
    expect(title.fontFamily, startsWith('Newsreader'));
    expect(title.fontSize, 24);
    expect(title.fontWeight, FontWeight.w600);
    expect(title.letterSpacing, -0.6);
  });

  testWidgets('while the looks are styled: one skeleton, labelled with the plan', (
    tester,
  ) async {
    final plan = DayPlan(
      date: appToday(),
      occasion: DayOccasion.workDay,
      dress: DressLevel.smartCasual,
    );
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(_StubService(_frame(needsStyling: true, plan: plan)), plans: [plan]),
    );
    await _settle(tester);

    expect(find.byType(OutfitCardSkeleton), findsOneWidget);
    expect(find.text('STYLING WORK DAY…'), findsOneWidget);
  });

  testWidgets('shows the weekly usage meter for free users', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame())));
    await _settle(tester);

    // Shows "of 10" (display-only) though the stub's backend cap is 21.
    expect(find.text('0 of 10 outfit ideas used this week'), findsOneWidget);
    expect(find.text('Get unlimited'), findsOneWidget);
  });

  testWidgets('shows the next 7 days with today filled', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame())));
    await _settle(tester);

    expect(find.text('Your next 7 days'), findsOneWidget);
    final heading = tester.widget<Text>(find.text('Your next 7 days')).style!;
    expect(heading.fontFamily, startsWith('Newsreader'));
    expect(heading.fontSize, 24);
    expect(heading.fontWeight, FontWeight.w600);
    expect(heading.letterSpacing, -0.6);
    // No planned count and no legend line.
    expect(find.textContaining('of 7 planned'), findsNothing);
    expect(find.textContaining('Filled = planned'), findsNothing);
    expect(find.text('Tomorrow · No plan yet'), findsOneWidget);
  });

  testWidgets('shop the look shows the top wardrobe gap', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame()),
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
    final heading = tester.widget<Text>(find.text('Shop the look')).style!;
    expect(heading.fontFamily, startsWith('Newsreader'));
    expect(heading.fontSize, 24);
    // No picks count pill and no commission line on Today.
    expect(find.textContaining(RegExp(r'picks? for you')), findsNothing);
    expect(find.textContaining('commission'), findsNothing);
  });

  testWidgets("shop the look shows today's picks under why", (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    TodayShop shop(String kind, String title) => TodayShop.fromJson({
      'kind': kind,
      'title': title,
      'products': [
        for (final n in ['Mac', 'Cap'])
          {
            'id': 'p-$n',
            'name': n,
            'brand': 'boohoo',
            'category': 'outerwear',
            'price_cents': 4500,
            'currency': 'USD',
            'image_url': '',
            'product_url': 'https://www.awin1.com/$n',
            'retailer': 'boohoo',
          },
      ],
    });
    const gaps = GapAnalysis(
      gaps: [
        GapItem(
          category: 'shoes',
          have: 0,
          recommended: 3,
          reason: 'You have 0 shoes.',
          outfitsUnlocked: 6,
        ),
      ],
      isTeaser: false,
    );
    await tester.pumpWidget(
      _host(
        _StubService(_frame(), shop: shop('rain', "For today's rain")),
        gaps: gaps,
      ),
    );
    await _settle(tester);
    expect(find.text("For today's rain"), findsOneWidget);
    expect(find.text('Mac'), findsOneWidget);
    expect(find.text('Cap'), findsOneWidget);
    expect(find.text('\$45 USD'), findsNWidgets(2));
    expect(find.text('Fill a gap: shoes'), findsOneWidget);

    // What today's plan is missing: the gap card would only repeat it.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      _host(
        _StubService(
          _frame(),
          shop: shop('missing', "To complete today's look"),
        ),
        gaps: gaps,
      ),
    );
    await _settle(tester);
    expect(find.text("To complete today's look"), findsOneWidget);
    expect(find.text('Fill a gap: shoes'), findsNothing);
  });

  testWidgets('weather credit sits at the bottom, below the week strip', (
    tester,
  ) async {
    final json = _frame().toJson()
      ..['weather'] = {'temp_c': 7.2, 'feels_like_c': 4.1, 'condition': 'rain'}
      ..['weather_attribution'] = {
        'service_name': 'Apple Weather',
        'logo_light_url': 'https://example.test/light.png',
        'logo_dark_url': 'https://example.test/dark.png',
        'legal_url': 'https://example.test/legal',
      };
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(TodayDashboard.fromJson(json))));
    await _settle(tester);

    expect(find.text('7°C, feels 4° · Rain'), findsOneWidget);
    // Date on the left, weather on the right of the same line.
    final date = tester.getRect(
      find.textContaining(RegExp(r'^[A-Z]{3}, [A-Z]{3} \d+$')),
    );
    final pill = tester.getRect(find.text('7°C, feels 4° · Rain'));
    expect((date.center.dy - pill.center.dy).abs(), lessThan(4));
    expect(pill.left, greaterThan(date.right));
    expect(
      pill.right,
      closeTo(1200 - 16 - 12, 2),
    ); // pill's padding inside the gutter
    final credit = tester.getTopLeft(find.text('Data sources')).dy;
    expect(
      credit,
      greaterThan(tester.getTopLeft(find.text('Your next 7 days')).dy),
    );
    expect(
      credit,
      greaterThan(tester.getTopLeft(find.text('7°C, feels 4° · Rain')).dy),
    );
  });

  testWidgets('a planned tomorrow fills the strip and the tomorrow card', (
    tester,
  ) async {
    final tomorrow = nextSevenDays()[1];
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame()),
        plans: [
          DayPlan(
            date: tomorrow,
            occasion: DayOccasion.workDay,
            dress: DressLevel.smartCasual,
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text('Tomorrow · Work day · Smart casual'), findsOneWidget);
    expect(find.text('Your outfit will be ready by 10 pm'), findsOneWidget);
    expect(find.text('Edit'), findsOneWidget);
  });

  testWidgets("today's plan shows as a pill under the weather", (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame()),
        plans: [
          DayPlan(
            date: appToday(),
            occasion: DayOccasion.school,
            dress: DressLevel.smartCasual,
            note: "Parents' meeting",
          ),
        ],
      ),
    );
    await _settle(tester);

    expect(find.text("Parents' meeting · Smart casual"), findsOneWidget);
  });

  testWidgets('a long name stays on one line, cut with an ellipsis', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _stubGeolocator(tester);
    final json = _frame().toJson()
      ..['user'] = {'name': 'Bartholomew Maximilian Featherstonehaugh'};
    await tester.pumpWidget(_host(_StubService(TodayDashboard.fromJson(json))));
    await _settle(tester);

    final greeting = find.textContaining('Bartholomew');
    final widget = tester.widget<Text>(greeting);
    // Set as in the Stitch mock: Newsreader 30, semibold, tight tracking.
    expect(widget.style?.fontFamily, startsWith('Newsreader'));
    expect(widget.style?.fontSize, 30);
    expect(widget.style?.fontWeight, FontWeight.w600);
    expect(widget.style?.letterSpacing, -0.75);
    expect(widget.style?.height, 1.25);
    expect(widget.maxLines, 1);
    expect(widget.overflow, TextOverflow.ellipsis);
    final line = tester.renderObject<RenderParagraph>(greeting);
    expect(line.didExceedMaxLines, isTrue); // really was cut
    expect(tester.getRect(greeting).right, lessThanOrEqualTo(390 - 16));
  });

  testWidgets('date + weather share a line even on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    _stubGeolocator(tester);
    final json = _frame().toJson()
      ..['weather'] = {
        'temp_c': -12.4,
        'feels_like_c': -21.0,
        'condition': 'thunderstorm',
      };
    await tester.pumpWidget(_host(_StubService(TodayDashboard.fromJson(json))));
    await _settle(tester);

    // No overflow error (the pill ellipsizes) and it stays on screen.
    expect(tester.takeException(), isNull);
    final pill = tester.getRect(find.textContaining('feels -21°'));
    expect(pill.right, lessThanOrEqualTo(320 - 16));
  });

  testWidgets('the bell shows a dot while notifications are unread', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(
      _host(
        _StubService(_frame()),
        notifications: sampleNotifications(DateTime.now()),
      ),
    );
    await _settle(tester);

    expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
  });

  testWidgets('no shop section without picks or gaps', (tester) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame())));
    await _settle(tester);

    expect(find.text('Shop the look'), findsNothing);
  });

  testWidgets('shows the resume banner with 0/8 when nothing is saved', (
    tester,
  ) async {
    _tallSurface(tester);
    _stubGeolocator(tester);
    await tester.pumpWidget(_host(_StubService(_frame())));
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
        _StubService(_frame()),
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
        _StubService(_frame()),
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
