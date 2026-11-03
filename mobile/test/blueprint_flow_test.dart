import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/models/style_blueprint_draft.dart';
import 'package:mobile/modules/onboarding/onboarding_controller.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_aesthetics_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_color_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_fit_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_goals_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_identity_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_palettes_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_reveal_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_shopping_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_work_screen.dart';
import 'package:mobile/modules/onboarding/screens/wardrobe_setup_screen.dart';
import 'package:mobile/modules/shop/shop_service.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class _NoopShopService extends ShopService {
  _NoopShopService() : super(Dio());

  @override
  Future<void> prefetchFeed() async {}
}

/// Records what each step posted without touching the network.
class _StubService extends OnboardingService {
  _StubService() : super(Dio());

  final calls = <String, Map<String, dynamic>>{};

  /// Every call, in order — to check step 1 is saved before step 2.
  final order = <String>[];

  /// Fails this many step 1 saves before succeeding.
  int identityFailures = 0;

  /// When set, step 1's save waits on it (an in-flight request).
  Completer<void>? identityGate;

  @override
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) async {
    order.add('identity');
    calls['identity'] = {
      'shopping_style': shoppingStyle,
      'age_range': ageRange,
    };
    await identityGate?.future;
    if (identityFailures > 0) {
      identityFailures--;
      throw const ApiException(code: 'network', message: 'offline');
    }
    return 'style_blueprint_2';
  }

  @override
  Future<String> setBlueprintFit({
    required String? bodyShape,
    required String fitTops,
    required String fitBottoms,
  }) async {
    order.add('fit');
    calls['fit'] = {
      'body_shape': bodyShape,
      'fit_tops': fitTops,
      'fit_bottoms': fitBottoms,
    };
    return 'style_blueprint_3';
  }

  @override
  Future<String> completeBlueprint() async {
    order.add('complete');
    calls['complete'] = {};
    return 'today_dashboard';
  }

  @override
  Future<String> setBlueprintAesthetics(
    List<String> aesthetics, {
    List<String> micro = const [],
  }) async {
    calls['aesthetics'] = {
      'style_aesthetics': aesthetics,
      'micro_aesthetics': micro,
    };
    return 'style_blueprint_4';
  }

  @override
  Future<String> setBlueprintColor({
    required int? skinShade,
    required String? undertone,
  }) async {
    calls['color'] = {'skin_shade': skinShade, 'undertone': undertone};
    return 'style_blueprint_5';
  }

  @override
  Future<String> setBlueprintPalettes({
    required List<String> palettes,
    List<String> avoid = const [],
  }) async {
    calls['palettes'] = {'color_palettes': palettes, 'avoid_colors': avoid};
    return 'style_blueprint_6';
  }

  @override
  Future<String> setBlueprintWork({
    required List<String> occupations,
    required String? occupationOther,
    required String? dressCode,
    required String dayFormality,
    required String impressionGoal,
  }) async {
    calls['work'] = {
      'occupations': occupations,
      'occupation_other': occupationOther,
      'dress_code': dressCode,
      'day_formality': dayFormality,
      'impression_goal': impressionGoal,
    };
    return 'style_blueprint_7';
  }

  @override
  Future<String> setBlueprintShopping({
    required List<String> feelings,
    required String accessories,
    required String brandTier,
  }) async {
    calls['shopping'] = {
      'shopping_feelings': feelings,
      'accessories': accessories,
      'brand_tier': brandTier,
    };
    return 'style_blueprint_8';
  }

  @override
  Future<String> setBlueprintGoals({
    required List<String> feelings,
    required List<String> goals,
  }) async {
    calls['goals'] = {'three_month_feelings': feelings, 'style_goals': goals};
    return 'style_blueprint_reveal';
  }
}

/// Every blueprint screen prefills from the controller's draft, so seeding it
/// is how a "resumed onboarding" is simulated.
ProviderContainer _container(_StubService service) {
  return ProviderContainer(
    overrides: [
      onboardingServiceProvider.overrideWithValue(service),
      // Step 1 prefetches the shop feed; keep it off the network.
      shopServiceProvider.overrideWithValue(_NoopShopService()),
    ],
  );
}

/// The real seven-step router, so a step's `pushNamed` onward actually
/// resolves — plus a stub for wardrobe setup, which the reveal hands off to
/// and which needs providers this test doesn't stand up.
Widget _host(ProviderContainer container, {required String initialLocation}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: BlueprintIdentityScreen.path,
        name: BlueprintIdentityScreen.name,
        builder: (_, _) => const BlueprintIdentityScreen(),
      ),
      GoRoute(
        path: BlueprintFitScreen.path,
        name: BlueprintFitScreen.name,
        builder: (_, _) => const BlueprintFitScreen(),
      ),
      GoRoute(
        path: BlueprintAestheticsScreen.path,
        name: BlueprintAestheticsScreen.name,
        builder: (_, _) => const BlueprintAestheticsScreen(),
      ),
      GoRoute(
        path: BlueprintColorScreen.path,
        name: BlueprintColorScreen.name,
        builder: (_, _) => const BlueprintColorScreen(),
      ),
      GoRoute(
        path: BlueprintPalettesScreen.path,
        name: BlueprintPalettesScreen.name,
        builder: (_, _) => const BlueprintPalettesScreen(),
      ),
      GoRoute(
        path: BlueprintWorkScreen.path,
        name: BlueprintWorkScreen.name,
        builder: (_, _) => const BlueprintWorkScreen(),
      ),
      GoRoute(
        path: BlueprintShoppingScreen.path,
        name: BlueprintShoppingScreen.name,
        builder: (_, _) => const BlueprintShoppingScreen(),
      ),
      GoRoute(
        path: BlueprintGoalsScreen.path,
        name: BlueprintGoalsScreen.name,
        builder: (_, _) => const BlueprintGoalsScreen(),
      ),
      GoRoute(
        path: BlueprintRevealScreen.path,
        name: BlueprintRevealScreen.name,
        builder: (_, _) => const BlueprintRevealScreen(),
      ),
      GoRoute(
        path: WardrobeSetupScreen.path,
        name: WardrobeSetupScreen.name,
        builder: (_, _) => const Scaffold(body: Text('wardrobe setup')),
      ),
    ],
  );
  addTearDown(router.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

/// Taps a label, scrolling the (long, scrolling) step form to it first — the
/// default 800x600 test window shows only the top of most steps.
Future<void> _tap(WidgetTester tester, String label) async {
  final finder = find.text(label);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pump();
}

void main() {
  // A realistic phone viewport: the steps are long forms and several would
  // otherwise report overflow purely from the small default test window.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('every step renders without overflowing or throwing', (
    tester,
  ) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    const locations = <String>[
      BlueprintIdentityScreen.path,
      BlueprintFitScreen.path,
      BlueprintAestheticsScreen.path,
      BlueprintColorScreen.path,
      BlueprintPalettesScreen.path,
      BlueprintWorkScreen.path,
      BlueprintShoppingScreen.path,
      BlueprintGoalsScreen.path,
      BlueprintRevealScreen.path,
    ];

    for (final location in locations) {
      await tester.pumpWidget(_host(container, initialLocation: location));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: '$location failed to build',
      );
    }
  });

  testWidgets('step 1 requires a shopping style but not an age range', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );

    // Nothing selected: Continue is inert.
    await _tap(tester, 'Continue');
    expect(service.calls, isEmpty);

    // Shopping style alone is enough — the age question stays unanswered and
    // is transmitted as an explicit null skip.
    await _tap(tester, 'Men’s Fashion');
    await _tap(tester, 'Continue');

    expect(service.calls['identity'], {
      'shopping_style': 'mens',
      'age_range': null,
    });
  });

  testWidgets('a completed step advances to the next one', (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );
    expect(find.text('Step 1 of 8'), findsOneWidget);

    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 8'), findsOneWidget);
    expect(find.text('Which body shape feels closest?'), findsOneWidget);
  });

  testWidgets('steps move on without waiting, and save in order', (
    tester,
  ) async {
    final service = _StubService()..identityGate = Completer<void>();
    final container = _container(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );

    await _tap(tester, 'Men’s Fashion');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();

    // The save is still in flight, yet step 2 is up — and already knows the
    // answer, so it shows the men's set.
    expect(find.text('Step 2 of 8'), findsOneWidget);
    expect(find.text('Which build feels closest?'), findsOneWidget);

    // Step 2 moves on too, but its save queues behind step 1's.
    await _tap(tester, 'Trapezoid');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 8'), findsOneWidget);
    expect(service.order, ['identity']);

    service.identityGate!.complete();
    await tester.pumpAndSettle();
    expect(service.order, ['identity', 'fit']);
  });

  testWidgets('a failed step 1 save is retried before step 2 saves', (
    tester,
  ) async {
    final service = _StubService()..identityFailures = 1;
    final container = _container(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );

    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 8'), findsOneWidget);

    await _tap(tester, 'Hourglass');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();

    expect(service.order, ['identity', 'identity', 'fit']);
    expect(find.text('Step 3 of 8'), findsOneWidget);
  });

  testWidgets('steps move on while saving; a stuck save surfaces at the end', (
    tester,
  ) async {
    final service = _StubService()..identityFailures = 99;
    final container = _container(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );

    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();
    await _tap(tester, 'Hourglass');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();

    // Step 1 can't be saved, so step 2's save is held back behind it — but
    // the user still moved on, and neither answer is lost.
    expect(find.text('Step 3 of 8'), findsOneWidget);
    expect(service.order, ['identity', 'identity']);
    final draft = container.read(onboardingControllerProvider);
    expect(draft.shoppingStyle, 'womens');
    expect(draft.blueprint.bodyShape, 'hourglass');

    // Completing the blueprint waits for every save, so that's where it fails.
    await expectLater(
      container.read(onboardingControllerProvider.notifier).completeBlueprint(),
      throwsA(isA<ApiException>()),
    );
    expect(service.calls.containsKey('complete'), isFalse);

    // Once step 1 goes through, the held-back save follows it, in order.
    service.identityFailures = 0;
    await container
        .read(onboardingControllerProvider.notifier)
        .completeBlueprint();
    expect(service.order.sublist(service.order.length - 3), [
      'identity',
      'fit',
      'complete',
    ]);
  });

  testWidgets('step 1 age chips toggle off so the question stays skippable', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );
    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, '25–34');
    await _tap(tester, '25–34'); // tapping again clears it
    await _tap(tester, 'Continue');
    expect(service.calls['identity']!['age_range'], isNull);
  });

  Future<(_StubService, ProviderContainer)> fitStep(
    WidgetTester tester,
    String shoppingStyle,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: shoppingStyle, ageRange: null);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintFitScreen.path),
    );
    return (service, container);
  }

  testWidgets('back on a resumed step opens the previous step', (tester) async {
    await fitStep(tester, 'mens'); // starts at step 2 alone, like a resume
    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 8'), findsOneWidget);
  });

  testWidgets('system back on a resumed step opens the previous step', (
    tester,
  ) async {
    await fitStep(tester, 'mens');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 8'), findsOneWidget);
  });

  testWidgets('back after continuing pops to the step underneath', (
    tester,
  ) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintIdentityScreen.path),
    );
    // Nothing under step 1 here, so it has no back button.
    expect(find.byTooltip('Go back'), findsNothing);

    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Go back'));
    await tester.pumpAndSettle();

    expect(find.text('Step 1 of 8'), findsOneWidget);
    expect(find.byTooltip('Go back'), findsNothing);
  });

  testWidgets('step 2 names women’s shapes and saves the backend value', (
    tester,
  ) async {
    final (service, _) = await fitStep(tester, 'womens');

    expect(find.text('Which body shape feels closest?'), findsOneWidget);
    expect(find.text('Trapezoid'), findsNothing);
    await _tap(tester, 'Pear');
    await _tap(tester, 'Loose');
    await _tap(tester, 'Continue');

    expect(service.calls['fit'], {
      'body_shape': 'triangle',
      'fit_tops': 'loose',
      'fit_bottoms': 'relaxed',
    });
  });

  testWidgets('step 2 shows the men’s builds and segmented fit', (
    tester,
  ) async {
    final (service, _) = await fitStep(tester, 'mens');

    expect(find.text('Which build feels closest?'), findsOneWidget);
    expect(find.text('Trapezoid'), findsOneWidget);
    expect(find.text('Hourglass'), findsNothing);
    expect(find.text('Pear'), findsNothing);
    await _tap(tester, 'Trapezoid');
    // Trouser fit: Slim / Straight / Relaxed map to skinny / relaxed / baggy.
    // No value pill: each stop is named once, on its segment.
    expect(find.text('Straight'), findsOneWidget);
    final trouserRelaxed = find.text('Relaxed').last;
    await tester.ensureVisible(trouserRelaxed);
    await tester.pumpAndSettle();
    await tester.tap(trouserRelaxed);
    await tester.pump();
    await _tap(tester, 'Continue');

    expect(service.calls['fit'], {
      'body_shape': 'trapezoid',
      'fit_tops': 'regular',
      'fit_bottoms': 'baggy',
    });
  });

  testWidgets('step 2 is gender-neutral for prefer not to say', (tester) async {
    final (service, _) = await fitStep(tester, 'prefer_not_to_say');

    expect(find.text('Which shape feels closest?'), findsOneWidget);
    expect(find.text('Hourglass'), findsNothing);
    expect(find.text('Oversized'), findsOneWidget);
    await _tap(tester, 'Fuller hips');
    await _tap(tester, 'Continue');

    expect(service.calls['fit']!['body_shape'], 'triangle');
  });

  testWidgets('step 2 fit control follows a drag to the far option', (
    tester,
  ) async {
    final (service, _) = await fitStep(tester, 'womens');

    await _tap(tester, 'Hourglass');
    final from = find.text('Slim fitted');
    await tester.ensureVisible(from);
    await tester.pumpAndSettle();
    // Drag the top-fit thumb from the first option across to the last.
    await tester.drag(from, const Offset(400, 0));
    await tester.pumpAndSettle();
    await _tap(tester, 'Continue');

    expect(service.calls['fit']!['fit_tops'], 'loose');
  });

  testWidgets('step 3 shows the men’s card set for a mens shopper', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: 'mens', ageRange: null);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintAestheticsScreen.path),
    );

    expect(find.text('Rugged'), findsOneWidget);
    expect(find.text('Smart Casual'), findsOneWidget);
    expect(find.text('Bohemian'), findsNothing);
    expect(find.text('Romantic'), findsNothing);
  });

  testWidgets('step 3 shows the women’s card set otherwise', (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: 'both', ageRange: null);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintAestheticsScreen.path),
    );

    expect(find.text('Bohemian'), findsOneWidget);
    expect(find.text('Romantic'), findsOneWidget);
    expect(find.text('Rugged'), findsNothing);
  });

  testWidgets('step 3 sends selections in card order, not tap order', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintAestheticsScreen.path),
    );

    await _tap(tester, 'Avant-Garde');
    await _tap(tester, 'Minimalist');
    await _tap(tester, 'Continue');

    expect(service.calls['aesthetics'], {
      'style_aesthetics': ['minimalist', 'avant_garde'],
      'micro_aesthetics': <String>[],
    });
  });

  testWidgets('step 3’s “Want to get more specific?” tags are saved too', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    // Men's card set: the same tags show.
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: 'mens', ageRange: null);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintAestheticsScreen.path),
    );

    // Closed at first.
    expect(find.text('Quiet Luxury'), findsNothing);
    await _tap(tester, 'Want to get more specific?');
    await tester.pumpAndSettle(); // let it finish opening
    await _tap(tester, '90s Slouch');
    await _tap(tester, 'Quiet Luxury');
    await _tap(tester, 'Minimalist');
    await _tap(tester, 'Continue');

    // In tag order, not tap order.
    expect(service.calls['aesthetics'], {
      'style_aesthetics': ['minimalist'],
      'micro_aesthetics': ['quiet_luxury', '90s_slouch'],
    });
    expect(
      container.read(onboardingControllerProvider).blueprint.microAesthetics,
      ['quiet_luxury', '90s_slouch'],
    );
  });

  testWidgets('step 4 needs a shade and an undertone, then saves both', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintColorScreen.path),
    );
    InkWell continueButton() => tester.widget<InkWell>(
      find.ancestor(of: find.text('Continue'), matching: find.byType(InkWell)),
    );

    expect(find.text('What’s your skin tone?'), findsOneWidget);
    // Nothing picked yet: no palette, and Continue is off.
    expect(find.text('Colours that flatter you'), findsNothing);
    expect(continueButton().onTap, isNull);

    await tester.tap(find.bySemanticsLabel('Shade 7 of 10'));
    await tester.pump();
    expect(find.text('Tone 07 Selected'), findsOneWidget);
    expect(find.text('Colours that flatter you'), findsOneWidget);
    expect(continueButton().onTap, isNull);

    await _tap(tester, 'Cool');
    await _tap(tester, 'Continue');
    expect(service.calls['color'], {'skin_shade': 7, 'undertone': 'cool'});
    expect(container.read(onboardingControllerProvider).blueprint.skinShade, 7);
  });

  testWidgets('step 4’s “Skip for now” moves on without an answer', (
    tester,
  ) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    // An earlier answer, cleared by skipping.
    final notifier = container.read(onboardingControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(
      blueprint: const StyleBlueprintDraft(skinShade: 4, undertone: 'warm'),
    );

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintColorScreen.path),
    );
    // Prefilled from the draft.
    expect(find.text('Tone 04 Selected'), findsOneWidget);

    await _tap(tester, 'Skip for now');
    expect(service.calls['color'], {'skin_shade': null, 'undertone': null});
    final blueprint = container.read(onboardingControllerProvider).blueprint;
    expect(blueprint.skinShade, isNull);
    expect(blueprint.undertone, isNull);
  });

  testWidgets('step 5 keeps the picked palettes in card order', (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintPalettesScreen.path),
    );
    InkWell continueButton() => tester.widget<InkWell>(
      find.ancestor(of: find.text('Continue'), matching: find.byType(InkWell)),
    );

    expect(find.text('Which colours do you gravitate toward?'), findsOneWidget);
    expect(continueButton().onTap, isNull);

    await _tap(tester, 'BOLD & BRIGHT');
    await _tap(tester, 'NEUTRALS');
    await _tap(tester, 'Continue');

    expect(
      container.read(onboardingControllerProvider).blueprint.colorPalettes,
      ['neutrals', 'bold_bright'],
    );
    expect(service.calls['palettes'], {
      'color_palettes': ['neutrals', 'bold_bright'],
      'avoid_colors': <String>[],
    });
    await tester.pumpAndSettle();
    expect(find.byType(BlueprintWorkScreen), findsOneWidget);
  });

  testWidgets('step 5’s “Colours I avoid” picks are kept', (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintPalettesScreen.path),
    );

    expect(
      find.text('e.g., bright orange, neon yellows, magenta'),
      findsOneWidget,
    );
    await _tap(tester, 'Add');
    await tester.pumpAndSettle();
    await _tap(tester, 'Magenta');
    await _tap(tester, 'Bright orange');
    await _tap(tester, 'Mustard');
    await _tap(tester, 'Done');
    await tester.pumpAndSettle();

    // The picks show as chips instead of the example; one is taken off.
    expect(
      find.text('e.g., bright orange, neon yellows, magenta'),
      findsNothing,
    );
    expect(find.text('Mustard'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Remove Mustard'));
    await tester.pump();
    expect(find.text('Mustard'), findsNothing);

    await _tap(tester, 'EARTH TONES');
    await _tap(tester, 'Continue');
    // In list order, not pick order.
    expect(container.read(onboardingControllerProvider).blueprint.avoidColors, [
      'bright_orange',
      'magenta',
    ]);
    expect(service.calls['palettes'], {
      'color_palettes': ['earth_tones'],
      'avoid_colors': ['bright_orange', 'magenta'],
    });
  });

  group('step 6', () {
    Future<(_StubService, ProviderContainer)> open(WidgetTester tester) async {
      final service = _StubService();
      final container = _container(service);
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _host(container, initialLocation: BlueprintWorkScreen.path),
      );
      return (service, container);
    }

    InkWell continueButton(WidgetTester tester) => tester.widget<InkWell>(
      find.ancestor(of: find.text('Continue'), matching: find.byType(InkWell)),
    );

    testWidgets('saves up to two occupations, the dress code, the typical '
        'day and the impression', (tester) async {
      final (service, _) = await open(tester);
      expect(continueButton(tester).onTap, isNull);

      await _tap(tester, 'Healthcare');
      await _tap(tester, 'Marketing');
      await _tap(tester, 'Student'); // a third: ignored
      await _tap(tester, 'Smart Casual');
      // The typical day starts on smart casual; move it to Business (the
      // slider's label, not the occupation chip above it).
      final business = find.text('Business').last;
      await tester.ensureVisible(business);
      await tester.pumpAndSettle();
      await tester.tap(business);
      await tester.pump();
      await _tap(tester, 'Both equally');
      await _tap(tester, 'Continue');

      expect(service.calls['work'], {
        // In list order.
        'occupations': ['marketing', 'healthcare'],
        'occupation_other': null,
        'dress_code': 'smart_casual',
        'day_formality': 'business',
        'impression_goal': 'both',
      });
    });

    testWidgets('“Not currently working” stands alone and skips the dress '
        'code', (tester) async {
      final (service, _) = await open(tester);
      // The dress-code chip, not the slider's label.
      final casual = find.text('Casual').first;
      await tester.ensureVisible(casual);
      await tester.pumpAndSettle();
      await tester.tap(casual);
      await tester.pump();
      await _tap(tester, 'Education');
      await _tap(tester, 'Not currently working');
      await _tap(tester, 'Dating / Social situations');
      await _tap(tester, 'Continue');

      expect(service.calls['work']?['occupations'], ['not_working']);
      expect(service.calls['work']?['dress_code'], isNull);
    });

    testWidgets('“Other” needs a description', (tester) async {
      final (service, _) = await open(tester);
      await _tap(tester, 'Other');
      await _tap(tester, 'Uniform');
      await _tap(tester, 'Work / Professional settings');
      expect(continueButton(tester).onTap, isNull);

      await tester.enterText(
        find.widgetWithText(
          TextField,
          'e.g. Architectural Restoration, '
          'Brand Strategist',
        ),
        'Florist',
      );
      await tester.pump();
      expect(find.text('7 / 40'), findsOneWidget);
      await _tap(tester, 'Continue');
      expect(service.calls['work']?['occupations'], ['other']);
      expect(service.calls['work']?['occupation_other'], 'Florist');
    });

    testWidgets('search narrows the occupations', (tester) async {
      await open(tester);
      await tester.enterText(
        find.widgetWithText(TextField, 'Search or pick below'),
        'tech',
      );
      await tester.pump();
      expect(find.text('Tech / Remote'), findsOneWidget);
      expect(find.text('Healthcare'), findsNothing);
      expect(find.text('Other'), findsOneWidget); // always offered
    });
  });

  testWidgets('step 7 takes up to three feelings, accessories and a brand '
      'type', (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintShoppingScreen.path),
    );
    InkWell continueButton() => tester.widget<InkWell>(
      find.ancestor(of: find.text('Continue'), matching: find.byType(InkWell)),
    );

    expect(find.text('Step 7 of 8'), findsOneWidget);
    expect(find.text('0 of 3 selected'), findsOneWidget);
    await _tap(tester, 'Ready for a change');
    await _tap(tester, 'Often frustrated');
    await _tap(tester, 'Confident and in control');
    await _tap(tester, 'It’s just a necessity'); // a fourth: ignored
    expect(find.text('3 of 3 selected'), findsOneWidget);
    expect(continueButton().onTap, isNull);

    await _tap(tester, 'Statement pieces');
    await _tap(tester, 'A high-low mix');
    await _tap(tester, 'Continue');

    expect(service.calls['shopping'], {
      // In list order.
      'shopping_feelings': ['confident', 'frustrated', 'exploring'],
      'accessories': 'statement',
      'brand_tier': 'mix',
    });
    await tester.pumpAndSettle();
    expect(find.byType(BlueprintGoalsScreen), findsOneWidget);
    expect(find.text('Step 8 of 8'), findsOneWidget);
  });

  testWidgets('step 8 takes several feelings and goals', (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintGoalsScreen.path),
    );
    final cta = find.widgetWithText(FilledButton, 'See My Style Blueprint');

    expect(
      find.text('Takes about 10 seconds. No card required.'),
      findsOneWidget,
    );
    expect(tester.widget<FilledButton>(cta).onPressed, isNull);

    await _tap(tester, 'Excited to get dressed, not stressed');
    await _tap(tester, 'Confident wherever I go');
    await _tap(tester, 'Discover my personal style');
    await _tap(tester, 'Spend less time choosing outfits');
    expect(find.text('2 SELECTED'), findsOneWidget);
    await _tap(tester, 'See My Style Blueprint');

    expect(service.calls['goals'], {
      // In list order.
      'three_month_feelings': ['confident_anywhere', 'excited_not_stressed'],
      'style_goals': ['time_saving', 'discover_style'],
    });
  });

  testWidgets('the reveal plays back what the steps captured', (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    // Seed a completed draft the way a real run through steps 1-7 would.
    final notifier = container.read(onboardingControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(
      shoppingStyle: 'womens',
      ageRange: '25-34',
      styleGoals: ['time_saving'],
      blueprint: const StyleBlueprintDraft(
        bodyShape: 'hourglass',
        fitTops: 'regular',
        fitBottoms: 'relaxed',
        styleAesthetics: ['minimalist', 'romantic'],
        undertone: 'warm',
        colorPalettes: ['earth_tones'],
        occupations: ['marketing'],
        dressCode: 'business_casual',
        impressionGoal: 'both',
        shoppingFeelings: ['confident'],
        accessories: 'minimal',
        brandTier: 'premium',
        threeMonthFeelings: ['confident_anywhere'],
      ),
    );

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintRevealScreen.path),
    );

    expect(find.textContaining('Minimalist, Romantic'), findsOneWidget);
    expect(find.textContaining('confident wherever you go'), findsOneWidget);
    expect(find.text('Build My Wardrobe'), findsOneWidget);

    // Every answer the flow collected is played back, under the heading it was
    // asked beneath.
    for (final (label, value) in const [
      ('Shopping for', 'Women’s fashion'),
      ('Age', '25–34'),
      ('Body shape', 'Hourglass'),
      ('Prefers', 'regular tops · relaxed bottoms'),
      ('Aesthetics', 'Minimalist · Romantic'),
      ('Undertone', 'Warm undertone'),
      ('Colours', 'Earth tones'),
      ('Work', 'Marketing'),
      ('Dress code', 'Business casual'),
      ('Shopping feels', 'Confident and in control'),
      ('Brands', 'Premium brands'),
      ('In three months', 'Confident wherever I go'),
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
      expect(find.text(value), findsOneWidget, reason: value);
    }
  });

  testWidgets('the reveal drops questions the user skipped', (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    final notifier = container.read(onboardingControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(
      shoppingStyle: 'mens',
      blueprint: const StyleBlueprintDraft(bodyShape: 'oval'),
    );

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintRevealScreen.path),
    );

    // Age, occupation and dress code are all skippable — an unanswered one
    // must not leave an empty row behind.
    expect(find.text('Body shape'), findsOneWidget);
    expect(find.text('Age'), findsNothing);
    expect(find.text('Work'), findsNothing);
    expect(find.text('Dress code'), findsNothing);
  });

  testWidgets('the reveal can go back to step 8 with answers intact', (
    tester,
  ) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintGoalsScreen.path),
    );
    await tester.pumpAndSettle();

    // Answer step 8 and advance to the reveal.
    await _tap(tester, 'Confident wherever I go');
    await _tap(tester, 'Spend less time choosing outfits');
    await _tap(tester, 'See My Style Blueprint');
    await tester.pumpAndSettle();
    expect(find.text('Build My Wardrobe'), findsOneWidget);

    // Back lands on step 8 with the same answers still selected.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Step 8 of 8'), findsOneWidget);
    // The CTA only enables once both of step 8's questions are answered, so an
    // enabled button proves the earlier answers survived the round trip. (The
    // "n selected" counter is below the fold in this lazy list.)
    final cta = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'See My Style Blueprint'),
    );
    expect(cta.onPressed, isNotNull);
  });

  testWidgets('the reveal degrades gracefully with an empty draft', (
    tester,
  ) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintRevealScreen.path),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Your Style, Defined'), findsOneWidget);
    expect(find.text('Build My Wardrobe'), findsOneWidget);
  });

  group('answering a one-answer question moves on to the next', () {
    ScrollPosition stepScroll(WidgetTester tester) => tester
        .state<ScrollableState>(
          // The page's own; step 2's shape grid has one inside it.
          find
              .descendant(
                of: find.byType(SingleChildScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position;

    Future<void> settleReveal(WidgetTester tester) async {
      await tester.pump(const Duration(milliseconds: 300)); // the pause
      await tester.pumpAndSettle(); // the glide
    }

    testWidgets('the next question scrolls into view', (tester) async {
      await fitStep(tester, 'womens');
      await tester.pumpAndSettle();
      expect(stepScroll(tester).pixels, 0);

      await tester.tap(find.text('Hourglass'));
      await settleReveal(tester);

      expect(stepScroll(tester).pixels, greaterThan(0));
      final question = tester.getRect(
        find.text('How do you prefer your clothes to fit?'),
      );
      final viewport = tester.getRect(find.byType(SingleChildScrollView));
      expect(
        viewport.top <= question.top && question.bottom <= viewport.bottom,
        isTrue,
      );
    });

    testWidgets('changing an answer later does not move the page', (
      tester,
    ) async {
      await fitStep(tester, 'womens');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Hourglass'));
      await settleReveal(tester);
      stepScroll(tester).jumpTo(0); // the user scrolls back up…
      await tester.pump();

      // …and changes their mind on the first question.
      await tester.tap(find.text('Pear'));
      await settleReveal(tester);
      expect(stepScroll(tester).pixels, 0);
    });
  });
}
