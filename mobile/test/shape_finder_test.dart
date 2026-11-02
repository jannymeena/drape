import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile/modules/onboarding/models/body_shapes.dart';
import 'package:mobile/modules/onboarding/models/measurements_draft.dart';
import 'package:mobile/modules/onboarding/onboarding_controller.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_aesthetics_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_fit_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_analyzing_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_avatar_reveal_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_finder_controller.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_intro_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_measure_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_photo_error_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_photo_review_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_photo_tips_screen.dart';
import 'package:mobile/modules/onboarding/shape_finder/shape_result_screen.dart';
import 'package:mobile/shared/theme/app_theme.dart';

class _StubService extends OnboardingService {
  _StubService() : super(Dio());

  final calls = <String, Map<String, dynamic>>{};

  @override
  Future<String> setBlueprintIdentity({
    required String shoppingStyle,
    required String? ageRange,
  }) async => 'style_blueprint_2';

  @override
  Future<String> setBlueprintFit({
    required String? bodyShape,
    required String fitTops,
    required String fitBottoms,
  }) async {
    calls['fit'] = {
      'body_shape': bodyShape,
      'fit_tops': fitTops,
      'fit_bottoms': fitBottoms,
    };
    return 'style_blueprint_3';
  }
}

/// Answers at once, without reading the photo.
class _FakeEstimator implements BodyShapeEstimator {
  bool photoUnreadable = false;

  static const _estimate = ShapeEstimate(
    best: 'hourglass',
    alternatives: ['triangle', 'rectangle'],
  );

  @override
  Future<ShapeEstimate> fromMeasurements(
    BodyShapeSet set,
    Map<MeasurementField, double> cm,
  ) async => _estimate;

  @override
  Future<ShapeEstimate> fromPhoto(BodyShapeSet set, XFile photo) async {
    if (photoUnreadable) throw const PhotoUnreadableException();
    return _estimate;
  }
}

GoRoute _route(String path, String name, Widget screen) =>
    GoRoute(path: path, name: name, builder: (_, _) => screen);

Widget _host(ProviderContainer container, {required String initialLocation}) {
  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      _route(
        BlueprintFitScreen.path,
        BlueprintFitScreen.name,
        const BlueprintFitScreen(),
      ),
      _route(
        BlueprintAestheticsScreen.path,
        BlueprintAestheticsScreen.name,
        const Scaffold(body: Text('step 3')),
      ),
      _route(
        ShapeIntroScreen.path,
        ShapeIntroScreen.name,
        const ShapeIntroScreen(),
      ),
      _route(
        ShapeMeasureScreen.path,
        ShapeMeasureScreen.name,
        const ShapeMeasureScreen(),
      ),
      _route(
        ShapePhotoTipsScreen.path,
        ShapePhotoTipsScreen.name,
        const ShapePhotoTipsScreen(),
      ),
      _route(
        ShapePhotoReviewScreen.path,
        ShapePhotoReviewScreen.name,
        const ShapePhotoReviewScreen(),
      ),
      _route(
        ShapeAnalyzingScreen.path,
        ShapeAnalyzingScreen.name,
        const ShapeAnalyzingScreen(),
      ),
      _route(
        ShapePhotoErrorScreen.path,
        ShapePhotoErrorScreen.name,
        const ShapePhotoErrorScreen(),
      ),
      _route(
        ShapeResultScreen.path,
        ShapeResultScreen.name,
        const ShapeResultScreen(),
      ),
      _route(
        ShapeAvatarRevealScreen.path,
        ShapeAvatarRevealScreen.name,
        const ShapeAvatarRevealScreen(),
      ),
    ],
  );
  addTearDown(router.dispose);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(theme: AppTheme.light, routerConfig: router),
  );
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

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

  late _StubService service;
  late _FakeEstimator estimator;

  Future<ProviderContainer> womenAtStep2(WidgetTester tester) async {
    service = _StubService();
    estimator = _FakeEstimator();
    final container = ProviderContainer(
      overrides: [
        onboardingServiceProvider.overrideWithValue(service),
        bodyShapeEstimatorProvider.overrideWithValue(estimator),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(onboardingControllerProvider.notifier)
        .setBlueprintIdentity(shoppingStyle: 'womens', ageRange: null);
    await tester.pumpWidget(
      _host(container, initialLocation: BlueprintFitScreen.path),
    );
    return container;
  }

  testWidgets('“Not sure?” opens the shape finder', (tester) async {
    await womenAtStep2(tester);
    await _tap(tester, find.text('Not sure?'));

    expect(find.text('Build your Atelier silhouette'), findsOneWidget);
    expect(find.text('Enter measurements'), findsOneWidget);
    expect(find.text('Use a photo instead'), findsOneWidget);
  });

  testWidgets('skipping saves step 2 as “Not sure” and moves on', (
    tester,
  ) async {
    await womenAtStep2(tester);
    await _tap(tester, find.text('Not sure?'));
    await _tap(tester, find.textContaining('Skip for now'));

    expect(find.text('step 3'), findsOneWidget);
    expect(service.calls['fit'], {
      'body_shape': null,
      'fit_tops': 'regular',
      'fit_bottoms': 'relaxed',
    });
  });

  testWidgets('measurements → result → reveal saves the chosen shape', (
    tester,
  ) async {
    await womenAtStep2(tester);
    // A fit answer made before "Not sure?" survives the detour.
    await _tap(tester, find.text('Loose'));
    await _tap(tester, find.text('Not sure?'));
    await _tap(tester, find.text('Enter measurements'));

    expect(find.text('Four quick measurements'), findsOneWidget);
    expect(find.text('Bust'), findsOneWidget); // women's wording
    final continueButton = find.text('Continue');
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), '92');
    await tester.enterText(fields.at(1), '70');
    await tester.pump();
    await _tap(tester, continueButton); // hips missing: nothing happens
    expect(find.text('Four quick measurements'), findsOneWidget);

    await tester.enterText(fields.at(2), '98');
    await tester.pump();
    await _tap(tester, continueButton);

    expect(find.text('Hourglass'), findsOneWidget);
    expect(
      find.text('Based on your bust 92 cm, waist 70 cm and hips 98 cm.'),
      findsOneWidget,
    );

    // A runner-up can be chosen instead.
    await _tap(tester, find.text('Pear'));
    expect(
      find.text('Hips wider than shoulders.'),
      findsOneWidget,
    ); // now the main description

    await _tap(tester, find.text('Yes, That’s Me'));
    expect(find.text('Meet yourself, styled.'), findsOneWidget);
    expect(find.textContaining('92 cm', findRichText: true), findsOneWidget);

    await _tap(tester, find.text('Let’s Style You'));
    expect(find.text('step 3'), findsOneWidget);
    expect(service.calls['fit'], {
      'body_shape': 'triangle',
      'fit_tops': 'loose',
      'fit_bottoms': 'relaxed',
    });
  });

  testWidgets('inches convert to centimetres', (tester) async {
    final container = await womenAtStep2(tester);
    await _tap(tester, find.text('Not sure?'));
    await _tap(tester, find.text('Enter measurements'));
    await _tap(tester, find.text('in'));
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.pump();

    final cm = container.read(shapeFinderProvider).cm[MeasurementField.waist];
    expect(cm, closeTo(76.2, 0.01));
  });

  testWidgets('photo path: a readable photo leads to the result', (
    tester,
  ) async {
    final container = await womenAtStep2(tester);
    await _tap(tester, find.text('Not sure?'));
    container
        .read(shapeFinderProvider.notifier)
        .setPhoto(XFile('/nonexistent/photo.jpg'));
    // Straight to the analysis, as "Use This Photo" does.
    unawaitedPush(tester, ShapeAnalyzingScreen.name);
    await tester.pumpAndSettle();

    expect(find.text('Hourglass'), findsOneWidget);
    expect(
      find.text('Your temporary photo has been securely deleted.'),
      findsOneWidget,
    );
    expect(find.text('Add measurements to sharpen sizing'), findsOneWidget);
  });

  testWidgets('photo path: an unreadable photo shows the error', (
    tester,
  ) async {
    final container = await womenAtStep2(tester);
    estimator.photoUnreadable = true;
    await _tap(tester, find.text('Not sure?'));
    container
        .read(shapeFinderProvider.notifier)
        .setPhoto(XFile('/nonexistent/photo.jpg'));
    unawaitedPush(tester, ShapeAnalyzingScreen.name);
    await tester.pumpAndSettle();

    expect(find.text('We couldn’t see your full body.'), findsOneWidget);

    // "I'll pick my shape myself" goes back to step 2's grid.
    await _tap(tester, find.text('I’ll pick my shape myself'));
    expect(find.text('Which body shape feels closest?'), findsOneWidget);
  });

  testWidgets('photo buttons wait for consent', (tester) async {
    await womenAtStep2(tester);
    await _tap(tester, find.text('Not sure?'));
    await _tap(tester, find.text('Use a photo instead'));

    expect(find.text('Upload a full-body photo'), findsOneWidget);
    final take = find.ancestor(
      of: find.text('Take Photo'),
      matching: find.byType(InkWell),
    );
    expect(tester.widget<InkWell>(take).onTap, isNull);

    await _tap(tester, find.byType(Checkbox));
    expect(tester.widget<InkWell>(take).onTap, isNotNull);
  });
}

/// Pushes [name] on the current router without awaiting the route's result.
void unawaitedPush(WidgetTester tester, String name) {
  GoRouter.of(tester.element(find.byType(Scaffold).last)).pushNamed(name);
}
