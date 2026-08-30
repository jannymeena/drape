import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/modules/auth/screens/login_screen.dart';
import 'package:mobile/modules/auth/screens/sign_up_screen.dart';
import 'package:mobile/modules/auth/screens/welcome_screen.dart';
import 'package:mobile/shared/theme/app_theme.dart';

/// Covers the redesigned welcome / login / sign-up screens: that they build at
/// a real phone size, and that the welcome carousel's signup-first CTA
/// ordering actually routes where it says it does.
///
/// OAuth buttons are behind FeatureFlags (off in tests without the dart-defines
/// and off-platform), so these assert on the parts that always render.
void main() {
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

  /// The three auth routes plus stubs for everywhere they navigate, so a CTA
  /// tap resolves instead of asserting on a missing GoRouter.
  Widget host(String initialLocation) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: WelcomeScreen.path,
          name: WelcomeScreen.name,
          builder: (_, _) => const WelcomeScreen(),
        ),
        GoRoute(
          path: LoginScreen.path,
          name: LoginScreen.name,
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: SignUpScreen.path,
          name: SignUpScreen.name,
          builder: (_, _) => const SignUpScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    return ProviderScope(
      child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
    );
  }

  testWidgets('login renders its title, form and footer link', (tester) async {
    await tester.pumpWidget(host(LoginScreen.path));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.textContaining('Create one free'), findsOneWidget);
  });

  testWidgets('sign-up renders the title, consent copy and CTA',
      (tester) async {
    await tester.pumpWidget(host(SignUpScreen.path));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Create Account'), findsAtLeastNWidgets(1));
    // PIPEDA line is a promise we make on this screen - it must not silently
    // drop out of the layout.
    expect(
      find.text('Your data is stored securely in Canada. 🇨🇦'),
      findsOneWidget,
    );
    expect(find.textContaining('Terms'), findsOneWidget);
    expect(find.textContaining('Already have an account?'), findsOneWidget);
  });

  testWidgets('welcome ends on the signup-first slide', (tester) async {
    await tester.pumpWidget(host(WelcomeScreen.path));
    await tester.pumpAndSettle();

    // Advance to the last slide.
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(i == 0 ? 'Get Started' : 'Next'));
      await tester.pumpAndSettle();
    }

    expect(find.text('Every morning.\n10 seconds.\nDone.'), findsOneWidget);
    expect(find.text('Create My Account'), findsOneWidget);
    expect(find.textContaining('Already have an account?'), findsOneWidget);
    // The old ordering had these the other way round.
    expect(find.text('Sign In'), findsNothing);
  });

  testWidgets('the CTA sits at the same height on every slide', (tester) async {
    await tester.pumpWidget(host(WelcomeScreen.path));
    await tester.pumpAndSettle();

    // Regression: the title block and a Spacer used to split the free space,
    // so a short title left slack *below* the button and it drifted up and
    // down as you swiped.
    final tops = <double>[];
    for (final label in ['Get Started', 'Next', 'Create My Account']) {
      tops.add(tester.getTopLeft(find.text(label)).dy);
      if (label != 'Create My Account') {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
    }

    expect(
      tops.toSet(),
      hasLength(1),
      reason: 'the CTA must not move between slides: $tops',
    );
  });

  testWidgets('every slide uses the one title and subtitle style',
      (tester) async {
    await tester.pumpWidget(host(WelcomeScreen.path));
    await tester.pumpAndSettle();

    final titles = <TextStyle?>[];
    final subtitles = <TextStyle?>[];
    const copy = [
      ('You already own the\nperfect outfit.', 'ZOURA finds it every morning.'),
      (
        'Scan. Tag. Done.',
        "Point at any item and we'll handle the rest. No typing, no tagging.",
      ),
      (
        'Every morning.\n10 seconds.\nDone.',
        'Your AI stylist, powered by your actual wardrobe.',
      ),
    ];
    for (final (i, (title, subtitle)) in copy.indexed) {
      titles.add(tester.widget<Text>(find.text(title)).style);
      subtitles.add(tester.widget<Text>(find.text(subtitle)).style);
      if (i < 2) {
        await tester.tap(find.text(i == 0 ? 'Get Started' : 'Next'));
        await tester.pumpAndSettle();
      }
    }

    for (final styles in [titles, subtitles]) {
      expect(styles.map((s) => s?.fontSize).toSet(), hasLength(1));
      expect(styles.map((s) => s?.fontWeight).toSet(), hasLength(1));
      expect(styles.map((s) => s?.height).toSet(), hasLength(1));
    }
  });

  testWidgets('slide copy wraps to the viewport instead of being scaled down',
      (tester) async {
    // A FittedBox around the caption hands the text unbounded width, so a long
    // subtitle lays out on one line and the block is scaled to fit — same
    // TextStyle, visibly smaller type on that slide. Catch it by checking the
    // text actually lays out within the screen.
    await tester.pumpWidget(host(WelcomeScreen.path));
    await tester.pumpAndSettle();

    final width = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    for (final label in ['Get Started', 'Next', 'Create My Account']) {
      for (final text in find.byType(Text).evaluate()) {
        final size = tester.getSize(find.byWidget(text.widget));
        expect(
          size.width,
          lessThanOrEqualTo(width),
          reason: 'text laid out wider than the screen on the "$label" slide, '
              'which means something is scaling it instead of wrapping it',
        );
      }
      if (label != 'Create My Account') {
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('the welcome CTA goes to sign-up, the footer link to login',
      (tester) async {
    await tester.pumpWidget(host(WelcomeScreen.path));
    await tester.pumpAndSettle();
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text(i == 0 ? 'Get Started' : 'Next'));
      await tester.pumpAndSettle();
    }

    await tester.tap(find.text('Create My Account'));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);

    await tester.tap(find.textContaining('Already have an account?'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
