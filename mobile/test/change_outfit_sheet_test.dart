import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/widgets/change_outfit_sheet.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';

final _outfit = Outfit.fromJson({
  'id': 'o1',
  'occasion': 'work',
  'items': [
    {'item_id': 'coat', 'name': 'Camel Coat', 'category': 'outerwear'},
    {'item_id': 'knit', 'name': 'Ribbed Knit', 'category': 'tops'},
    {'item_id': 'pant', 'name': 'Charcoal Pant', 'category': 'bottoms'},
    {'item_id': 'boots', 'name': 'Chelsea Boots', 'category': 'shoes'},
  ],
});

/// Opens the sheet; returns a getter for what it popped with.
Future<ChangeOutfitResult? Function()> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  ChangeOutfitResult? result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await ChangeOutfitSheet.show(context, _outfit),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return () => result;
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pump();
}

void main() {
  testWidgets('the mock layout on the shared sheet, default 80% tall', (
    tester,
  ) async {
    await _open(tester);

    expect(find.byType(AppBottomSheet), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppBottomSheet)).height,
      closeTo(844 * 0.8, 1),
    );
    expect(find.text('What would you change?'), findsOneWidget);
    expect(
      find.text('Tell us what feels off and we will fix it.'),
      findsOneWidget,
    );
    expect(find.text('Pick up to 3'), findsOneWidget);
    for (final r in ChangeReason.values) {
      expect(find.text(r.label), findsOneWidget, reason: r.label);
    }
    expect(find.text('Keep these pieces'), findsOneWidget);
    for (final n in ['Camel Coat', 'Ribbed Knit', 'Charcoal Pant']) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.text('Not for me, do not show this again'), findsOneWidget);
    expect(find.text('Update this outfit'), findsOneWidget);
    expect(find.text('Regenerate: show me something new'), findsOneWidget);
    expect(find.text('Uses 1 of your 10 ideas this week.'), findsOneWidget);
  });

  testWidgets('at most three reasons; Other opens a note', (tester) async {
    await _open(tester);

    await _tap(tester, 'Too casual');
    await _tap(tester, 'Too warm');
    await _tap(tester, 'Other');
    expect(find.text('3 of 3'), findsOneWidget);
    expect(find.text('Tell us what you need'), findsOneWidget);

    // A fourth is ignored until one is unpicked.
    await _tap(tester, 'Not my style');
    expect(find.text('3 of 3'), findsOneWidget);
    await _tap(tester, 'Too warm');
    await _tap(tester, 'Not my style');
    expect(find.text('3 of 3'), findsOneWidget);
  });

  testWidgets('Update returns reasons, note, kept pieces, Not for me', (
    tester,
  ) async {
    final result = await _open(tester);

    await _tap(tester, 'Too casual');
    await _tap(tester, 'Other');
    await tester.enterText(find.byType(TextField), 'Warmer shoes');
    await tester.pump();
    expect(find.text('12 / 140'), findsOneWidget);
    await _tap(tester, 'Camel Coat'); // keep it
    expect(find.text('Keep'), findsOneWidget);
    await _tap(tester, 'Not for me, do not show this again');

    await tester.tap(find.text('Update this outfit'));
    await tester.pumpAndSettle();

    final update = result() as ChangeUpdate;
    expect(update.reasons, {ChangeReason.tooCasual, ChangeReason.other});
    expect(update.otherText, 'Warmer shoes');
    expect(update.keepItemIds, {'coat'});
    expect(update.notForMe, isTrue);
  });

  testWidgets('Update waits for feedback; Regenerate returns at once', (
    tester,
  ) async {
    final result = await _open(tester);

    await tester.tap(find.text('Update this outfit'));
    await tester.pumpAndSettle();
    expect(find.byType(ChangeOutfitSheet), findsOneWidget); // still open

    await tester.tap(find.text('Regenerate: show me something new'));
    await tester.pumpAndSettle();
    expect(result(), isA<ChangeRegenerate>());
  });
}
