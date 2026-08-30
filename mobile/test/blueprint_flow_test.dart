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
import 'package:mobile/modules/onboarding/screens/blueprint_habits_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_identity_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_lifestyle_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_reveal_screen.dart';
import 'package:mobile/modules/onboarding/screens/wardrobe_setup_screen.dart';
import 'package:mobile/shared/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

/// Records what each step posted without touching the network.
class _StubService extends OnboardingService {
  _StubService() : super(Dio());

  final calls = <String, Map<String, dynamic>>{};

  @override
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) async {
    calls['identity'] = {
      'shopping_style': shoppingStyle,
      'age_range': ageRange,
    };
    return 'style_blueprint_2';
  }

  @override
  Future<String> setBlueprintAesthetics(List<String> aesthetics) async {
    calls['aesthetics'] = {'style_aesthetics': aesthetics};
    return 'style_blueprint_4';
  }
}

/// Every blueprint screen prefills from the controller's draft, so seeding it
/// is how a "resumed onboarding" is simulated.
ProviderContainer _container(_StubService service) {
  return ProviderContainer(
    overrides: [onboardingServiceProvider.overrideWithValue(service)],
  );
}

/// The real seven-step router, so a step's `pushNamed` onward actually
/// resolves — plus a stub for wardrobe setup, which the reveal hands off to
/// and which needs providers this test doesn't stand up.
Widget _host(
  ProviderContainer container, {
  required String initialLocation,
}) {
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
        path: BlueprintLifestyleScreen.path,
        name: BlueprintLifestyleScreen.name,
        builder: (_, _) => const BlueprintLifestyleScreen(),
      ),
      GoRoute(
        path: BlueprintHabitsScreen.path,
        name: BlueprintHabitsScreen.name,
        builder: (_, _) => const BlueprintHabitsScreen(),
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
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
    ),
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
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3.0;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('every step renders without overflowing or throwing',
      (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    const locations = <String>[
      BlueprintIdentityScreen.path,
      BlueprintFitScreen.path,
      BlueprintAestheticsScreen.path,
      BlueprintColorScreen.path,
      BlueprintLifestyleScreen.path,
      BlueprintHabitsScreen.path,
      BlueprintGoalsScreen.path,
      BlueprintRevealScreen.path,
    ];

    for (final location in locations) {
      await tester.pumpWidget(_host(container, initialLocation: location));
      await tester.pump();
      expect(tester.takeException(), isNull,
          reason: '$location failed to build');
    }
  });

  testWidgets('step 1 requires a shopping style but not an age range',
      (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, initialLocation: BlueprintIdentityScreen.path));

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
    expect(find.text('Step 1 of 7'), findsOneWidget);

    await _tap(tester, 'Both / All Styles');
    await _tap(tester, 'Continue');
    await tester.pumpAndSettle();

    expect(find.text('Step 2 of 7'), findsOneWidget);
    expect(find.text('Which body shape feels closest?'), findsOneWidget);
  });

  testWidgets('step 1 age chips toggle off so the question stays skippable',
      (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, initialLocation: BlueprintIdentityScreen.path));
    await _tap(tester, 'Women’s Fashion');
    await _tap(tester, '25–34');
    await _tap(tester, '25–34'); // tapping again clears it
    await _tap(tester, 'Continue');
    expect(service.calls['identity']!['age_range'], isNull);
  });

  testWidgets('step 3 shows the men’s card set for a mens shopper',
      (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: 'mens', ageRange: null);

    await tester
        .pumpWidget(_host(container, initialLocation: BlueprintAestheticsScreen.path));

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

    await tester
        .pumpWidget(_host(container, initialLocation: BlueprintAestheticsScreen.path));

    expect(find.text('Bohemian'), findsOneWidget);
    expect(find.text('Romantic'), findsOneWidget);
    expect(find.text('Rugged'), findsNothing);
  });

  testWidgets('step 3 sends selections in card order, not tap order',
      (tester) async {
    final service = _StubService();
    final container = _container(service);
    addTearDown(container.dispose);

    await tester
        .pumpWidget(_host(container, initialLocation: BlueprintAestheticsScreen.path));

    await _tap(tester, 'Avant-Garde');
    await _tap(tester, 'Minimalist');
    await _tap(tester, 'Continue');

    expect(service.calls['aesthetics'], {
      'style_aesthetics': ['minimalist', 'avant_garde'],
    });
  });

  testWidgets('the reveal plays back what the steps captured', (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    // Seed a completed draft the way a real run through steps 1-7 would.
    final notifier = container.read(onboardingControllerProvider.notifier);
    notifier.state = notifier.state.copyWith(
      shoppingStyle: 'womens',
      blueprint: const StyleBlueprintDraft(
        bodyShape: 'hourglass',
        fitTops: 'regular',
        styleAesthetics: ['minimalist', 'romantic'],
        undertone: 'warm',
        colorPalettes: ['earth_tones'],
        threeMonthFeeling: 'confident_anywhere',
      ),
    );

    await tester.pumpWidget(_host(container, initialLocation: BlueprintRevealScreen.path));

    expect(find.textContaining('Minimalist, Romantic'), findsOneWidget);
    expect(find.text('Minimalist · Romantic'), findsOneWidget);
    expect(find.text('Hourglass, regular fit'), findsOneWidget);
    expect(find.text('Warm undertone'), findsOneWidget);
    expect(find.textContaining('confident wherever you go'), findsOneWidget);
    expect(find.text('Build My Wardrobe'), findsOneWidget);
  });

  testWidgets('the reveal degrades gracefully with an empty draft',
      (tester) async {
    final container = _container(_StubService());
    addTearDown(container.dispose);

    await tester.pumpWidget(_host(container, initialLocation: BlueprintRevealScreen.path));

    expect(tester.takeException(), isNull);
    expect(find.text('Your Style, Defined'), findsOneWidget);
    expect(find.text('Build My Wardrobe'), findsOneWidget);
  });
}
