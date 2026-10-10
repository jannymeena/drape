import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/modules/auth/screens/login_screen.dart';
import 'package:mobile/modules/auth/screens/sign_up_screen.dart';
import 'package:mobile/modules/onboarding/widgets/measurement_input.dart';
import 'package:mobile/modules/onboarding/widgets/measurement_step_scaffold.dart';
import 'package:mobile/shared/theme/app_theme.dart';
import 'package:mobile/shared/widgets/keyboard_dismiss_on_tap_outside.dart';

/// The app-root keyboard dismissal (see `app.dart`) exercised through real
/// screens, wired the way `DrapeApp` wires it: login and sign-up, an avatar
/// measurement step (number pad — no Done key on iOS), and a text field
/// inside a dialog (a separate route above the page).
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

  Widget dismissing(BuildContext _, Widget? child) =>
      KeyboardDismissOnTapOutside(child: child!);

  Widget authHost(String initialLocation) {
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
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
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: dismissing,
      ),
    );
  }

  final phones = TargetPlatformVariant(
    const {TargetPlatform.iOS, TargetPlatform.android},
  );

  Future<void> expectClosedAfterTapOn(WidgetTester tester, Finder outside) async {
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.tap(outside);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isFalse);
  }

  testWidgets('login: tapping the title closes the keyboard', (tester) async {
    await tester.pumpWidget(authHost(LoginScreen.path));
    await tester.pump();
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    await expectClosedAfterTapOn(tester, find.text('Welcome back'));
  }, variant: phones);

  testWidgets('login: email to password keeps the keyboard up', (tester) async {
    await tester.pumpWidget(authHost(LoginScreen.path));
    await tester.pump();
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    await tester.tap(find.byType(TextFormField).last);
    await tester.pump();
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: phones);

  testWidgets('sign-up: tapping outside the form closes the keyboard',
      (tester) async {
    await tester.pumpWidget(authHost(SignUpScreen.path));
    await tester.pump();
    await tester.tap(find.byType(TextFormField).first);
    await tester.pump();

    // The heading; the button below carries the same label.
    await expectClosedAfterTapOn(tester, find.text('Create Account').first);
  }, variant: phones);

  testWidgets('measurement step: tapping the title closes the number pad',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light,
          builder: dismissing,
          home: MeasurementStepScaffold(
            step: 4,
            stepLabel: 'WAIST',
            bodyPart: 'waist',
            title: 'Waist',
            description: 'Measure at the narrowest part of your torso.',
            canContinue: true,
            onContinue: () {},
            input: const MeasurementInput(),
          ),
        ),
      ),
    );
    // The guide's tip card overflows under the wide test font; not what
    // this test is about.
    tester.takeException();
    await tester.tap(find.byType(TextField));
    await tester.pump();

    await expectClosedAfterTapOn(
      tester,
      find.text('Measure at the narrowest part of your torso.'),
    );
  }, variant: phones);

  testWidgets('dialog: tapping the dialog title closes the keyboard',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: dismissing,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AlertDialog(
                  title: Text('Change email'),
                  content: TextField(autofocus: true),
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await expectClosedAfterTapOn(tester, find.text('Change email'));
    // Still inside the dialog — only the keyboard went away.
    expect(find.byType(AlertDialog), findsOneWidget);
  }, variant: phones);
}
