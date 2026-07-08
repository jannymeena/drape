import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/widgets/measurement_step_scaffold.dart';

/// Guards the shared chrome that all 8 avatar-measurement steps render through,
/// so they stay consistent: the `STEP n OF 8 — LABEL` marker, the title/copy,
/// and the button's enabled/disabled gating.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    bool canContinue = true,
    VoidCallback? onContinue,
  }) {
    return tester.pumpWidget(
      // ProviderScope: the scaffold reads analyticsProvider on Continue taps.
      ProviderScope(
        child: MaterialApp(
          home: MeasurementStepScaffold(
          step: 4,
          stepLabel: 'WAIST',
          bodyPart: 'waist',
          title: 'Waist',
          description: 'Measure at the narrowest part of your torso.',
            canContinue: canContinue,
            onContinue: onContinue,
            input: const SizedBox(key: Key('input')),
          ),
        ),
      ),
    );
  }

  testWidgets('renders the step marker, title and copy', (tester) async {
    await pump(tester);

    expect(find.text('STEP 4 OF 8 — WAIST'), findsOneWidget);
    // 'Waist' also appears in the MeasurementGuide tip card, so >= 1.
    expect(find.text('Waist'), findsWidgets);
    expect(find.text('Measure at the narrowest part of your torso.'),
        findsOneWidget);
    expect(find.byKey(const Key('input')), findsOneWidget);
    expect(find.text('Keep Going'), findsOneWidget);
  });

  testWidgets('button fires onContinue when enabled', (tester) async {
    var tapped = false;
    await pump(tester, onContinue: () => tapped = true);

    await tester.tap(find.text('Keep Going'));
    expect(tapped, isTrue);
  });

  testWidgets('button is inert when canContinue is false', (tester) async {
    var tapped = false;
    await pump(tester, canContinue: false, onContinue: () => tapped = true);

    await tester.tap(find.text('Keep Going'));
    expect(tapped, isFalse);
  });
}
