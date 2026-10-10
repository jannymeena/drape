import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/keyboard_dismiss_on_tap_outside.dart';

void main() {
  final first = FocusNode();
  final second = FocusNode();

  Widget app({required bool wrapped}) {
    const body = ColoredBox(
      key: Key('blank'),
      color: Colors.white,
      child: SizedBox(height: 200, width: 200),
    );
    final screen = Scaffold(
      body: Column(
        children: [
          TextField(key: const Key('first'), focusNode: first),
          TextField(key: const Key('second'), focusNode: second),
          body,
        ],
      ),
    );
    return MaterialApp(
      builder: (_, child) =>
          wrapped ? KeyboardDismissOnTapOutside(child: child!) : child!,
      home: screen,
    );
  }

  final phones = TargetPlatformVariant(
    const {TargetPlatform.iOS, TargetPlatform.android},
  );

  testWidgets('a tap outside the text field closes the keyboard', (tester) async {
    await tester.pumpWidget(app(wrapped: true));
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();
    expect(first.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();
    expect(first.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
  }, variant: phones);

  testWidgets('tapping another text field keeps the keyboard up', (tester) async {
    await tester.pumpWidget(app(wrapped: true));
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('second')));
    await tester.pump();
    expect(second.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);
  }, variant: phones);

  testWidgets('without the wrapper a phone keeps the keyboard open', (tester) async {
    await tester.pumpWidget(app(wrapped: false));
    await tester.tap(find.byKey(const Key('first')));
    await tester.pump();

    await tester.tap(find.byKey(const Key('blank')));
    await tester.pump();
    expect(first.hasFocus, isTrue);
  }, variant: phones);
}
