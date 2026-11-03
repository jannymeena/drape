// On-device checks, run against a deployed backend:
//
//   flutter test integration_test/ios_tbd_flow_test.dart \
//     -d <simulator> --dart-define-from-file=env/tbd.env \
//     --dart-define=SAMPLE_PHOTO=/absolute/path/to/full_body.jpg
//
// 1. MediaPipe body detection through the real native channel, on a sample
//    full-body photo (the system photo picker can't be driven from a test).
// 2. The whole Style Blueprint: sign up a fresh account, answer the 8 steps,
//    reach the reveal, and read the answers back from the backend.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/main.dart' as app;
import 'package:mobile/modules/onboarding/models/body_shapes.dart';
import 'package:mobile/modules/onboarding/onboarding_service.dart';
import 'package:mobile/modules/onboarding/shape_finder/body_reading.dart';
import 'package:mobile/modules/onboarding/shape_finder/measurement_shape.dart';
import 'package:mobile/modules/onboarding/shape_finder/pose_detector.dart';

const _samplePhoto = String.fromEnvironment('SAMPLE_PHOTO');

/// Pumps frames until [finder] shows (the app has endless animations, so
/// pumpAndSettle would never return).
Future<void> _waitFor(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
    if (finder.evaluate().isNotEmpty) return;
  }
  final onScreen = [
    for (final e in find.byType(Text).evaluate()) ?(e.widget as Text).data,
  ];
  fail('Timed out waiting for $finder; on screen: $onScreen');
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await _waitFor(tester, finder);
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tap(tester, find.text(text));

/// Continue, then wait for [next]'s heading.
Future<void> _continueTo(WidgetTester tester, String nextHeading) async {
  await _tapText(tester, 'Continue');
  await _waitFor(tester, find.text(nextHeading));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('MediaPipe reads a body from a photo on this device', (
    tester,
  ) async {
    expect(_samplePhoto, isNotEmpty, reason: 'pass --dart-define=SAMPLE_PHOTO');
    final poses = await const MediaPipePoseDetector().detect(
      XFile(_samplePhoto),
    );
    debugPrint('IOSCHECK poses found: ${poses.length}');
    final body = BodyReading.from(poses);
    final guides = body.suggestedGuides;
    final blur = body.suggestedFaceBlur;
    final widths = body.widthsAt(guides);
    final shape = shapeFromSignals(
      BodyShapeSet.womens,
      photoSignals(BodyShapeSet.womens, widths),
    );
    debugPrint(
      'IOSCHECK guides ${guides.shoulders.toStringAsFixed(3)} / '
      '${guides.waist.toStringAsFixed(3)} / ${guides.hips.toStringAsFixed(3)}; '
      'blur at ${blur.center} r=${blur.radius.toStringAsFixed(3)}; '
      'widths $widths; shape ${shape.best} (then ${shape.alternatives})',
    );
    expect(poses, hasLength(1));
  });

  testWidgets('sign up and complete the Style Blueprint against the backend', (
    tester,
  ) async {
    app.main();
    final email =
        'ios-sim-test+${DateTime.now().millisecondsSinceEpoch}@example.com';

    // Welcome → sign up.
    await _tapText(tester, 'Get Started');
    await _tapText(tester, 'Next');
    await _tapText(tester, 'Create My Account');
    await _waitFor(tester, find.text('Email address'));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), email);
    await tester.enterText(fields.at(1), 'Testpass123');
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    // The heading says it too; the button is the later one.
    await _tap(tester, find.text('Create Account').last);
    debugPrint('IOSCHECK signed up as $email');

    // 1 — who we shop for.
    await _waitFor(tester, find.text('Step 1 of 8'));
    await _tapText(tester, 'Women’s Fashion');
    await _continueTo(tester, 'Step 2 of 8');
    // 2 — shape.
    await _tapText(tester, 'Hourglass');
    await _continueTo(tester, 'Step 3 of 8');
    // 3 — styles.
    await _tapText(tester, 'Minimalist');
    await _continueTo(tester, 'Step 4 of 8');
    // 4 — skin tone.
    await _tap(tester, find.bySemanticsLabel('Shade 5 of 10'));
    await _tapText(tester, 'Warm');
    await _continueTo(tester, 'Step 5 of 8');
    // 5 — palettes.
    await _tapText(tester, 'EARTH TONES');
    await _continueTo(tester, 'Step 6 of 8');
    // 6 — work.
    await _tapText(tester, 'Healthcare');
    await _tapText(tester, 'Smart Casual');
    await _tapText(tester, 'Both equally');
    await _continueTo(tester, 'Step 7 of 8');
    // 7 — shopping and brands.
    await _tapText(tester, 'Confident and in control');
    await _tapText(tester, 'None at all');
    await _tapText(tester, 'Premium brands');
    await _continueTo(tester, 'Step 8 of 8');
    // 8 — goals.
    await _tapText(tester, 'Confident wherever I go');
    await _tapText(tester, 'Spend less time choosing outfits');
    await _tapText(tester, 'See My Style Blueprint');

    // The reveal builds (waits for every save), then shows the result.
    await _waitFor(tester, find.text('Reading your answers…'));
    debugPrint('IOSCHECK reveal: building');
    await _waitFor(tester, find.text('Build My Wardrobe'));
    debugPrint('IOSCHECK reveal: result');
    expect(find.textContaining('Worn with Confidence'), findsOneWidget);

    // Every answer reached the backend.
    final container = ProviderScope.containerOf(
      tester.element(find.text('Build My Wardrobe')),
    );
    final status = await container
        .read(onboardingServiceProvider)
        .getOnboardingStatus();
    final b = status.styleProfile;
    debugPrint(
      'IOSCHECK backend: next=${status.nextStep} shape=${b.bodyShape} '
      'styles=${b.styleAesthetics} shade=${b.skinShade} '
      'undertone=${b.undertone} palettes=${b.colorPalettes} '
      'work=${b.occupations} dress=${b.dressCode} '
      'feelings=${b.shoppingFeelings} brand=${b.brandTier} '
      'three=${b.threeMonthFeelings} goals=${status.styleGoals}',
    );
    expect(status.shoppingStyle, 'womens');
    expect(b.bodyShape, 'hourglass');
    expect(b.styleAesthetics, ['minimalist']);
    expect(b.skinShade, 5);
    expect(b.undertone, 'warm');
    expect(b.colorPalettes, ['earth_tones']);
    expect(b.occupations, ['healthcare']);
    expect(b.dressCode, 'smart_casual');
    expect(b.impressionGoal, 'both');
    expect(b.shoppingFeelings, ['confident']);
    expect(b.accessories, 'none');
    expect(b.brandTier, 'premium');
    expect(b.threeMonthFeelings, ['confident_anywhere']);
    expect(status.styleGoals, ['time_saving']);
    expect(status.nextStep, 'style_blueprint_reveal');
  });
}
