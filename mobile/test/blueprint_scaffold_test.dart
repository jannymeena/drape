import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/onboarding/widgets/blueprint_scaffold.dart';
import 'package:mobile/shared/theme/app_theme.dart';

/// The seven Style Blueprint steps only read as one flow if they share a
/// scaffold and a type scale. These guard both: the step chrome is derived
/// from a single `step` argument, and every question renders at the same size
/// no matter which screen it's on.
void main() {
  Widget host(Widget child) =>
      MaterialApp(theme: AppTheme.light, home: child);

  testWidgets('step chrome reports position out of the shared total',
      (tester) async {
    await tester.pumpWidget(host(BlueprintScaffold(
      step: 3,
      onContinue: () {},
      children: const [BlueprintQuestion(title: 'Which styles do you like?')],
    )));

    expect(find.text('Step 3 of $kBlueprintSteps'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, closeTo(3 / kBlueprintSteps, 0.001));
  });

  testWidgets('Continue is gated by canContinue', (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(BlueprintScaffold(
      step: 1,
      canContinue: false,
      onContinue: () => taps++,
      children: const [BlueprintQuestion(title: 'What do you shop for?')],
    )));

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(taps, 0, reason: 'a disabled Continue must not fire');

    await tester.pumpWidget(host(BlueprintScaffold(
      step: 1,
      onContinue: () => taps++,
      children: const [BlueprintQuestion(title: 'What do you shop for?')],
    )));
    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('loading swaps the label for a spinner and blocks taps',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(host(BlueprintScaffold(
      step: 2,
      loading: true,
      onContinue: () => taps++,
      children: const [BlueprintQuestion(title: 'Which body shape?')],
    )));

    expect(find.text('Continue'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('every question renders at one size across steps',
      (tester) async {
    final sizes = <double?>[];
    for (var step = 1; step <= kBlueprintSteps; step++) {
      await tester.pumpWidget(host(BlueprintScaffold(
        step: step,
        onContinue: () {},
        children: [BlueprintQuestion(title: 'Question $step')],
      )));
      sizes.add(
        tester.widget<Text>(find.text('Question $step')).style?.fontSize,
      );
    }

    expect(sizes.first, isNotNull);
    expect(sizes.toSet(), hasLength(1),
        reason: 'onboarding headings must not drift between steps: $sizes');
  });

  testWidgets('a question subtitle is smaller than its heading',
      (tester) async {
    await tester.pumpWidget(host(BlueprintScaffold(
      step: 4,
      onContinue: () {},
      children: const [
        BlueprintQuestion(
          title: 'What’s your undertone?',
          subtitle: 'A quick guess is fine.',
        ),
      ],
    )));

    final title =
        tester.widget<Text>(find.text('What’s your undertone?')).style;
    final subtitle =
        tester.widget<Text>(find.text('A quick guess is fine.')).style;
    expect(subtitle!.fontSize!, lessThan(title!.fontSize!));
  });
}
