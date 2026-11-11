import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';

Future<Future<String?>> _open(
  WidgetTester tester, {
  double heightFactor = 0.8,
  String? title,
  bool withActions = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  late Future<String?> result;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = AppBottomSheet.show<String>(
              context,
              builder: (context) => AppBottomSheet(
                heightFactor: heightFactor,
                title: title,
                actions: withActions
                    ? FilledButton(
                        onPressed: () => Navigator.of(context).pop('saved'),
                        child: const Text('Save'),
                      )
                    : null,
                child: Column(
                  children: [
                    for (var i = 0; i < 30; i++)
                      SizedBox(height: 60, child: Text('Row $i')),
                  ],
                ),
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
  return result;
}

void main() {
  testWidgets('80% tall by default, with the grabber on top', (tester) async {
    await _open(tester);
    expect(
      tester.getSize(find.byType(AppBottomSheet)).height,
      closeTo(844 * 0.8, 1),
    );
    // Grabber: the 40 x 4 bar centred at the top of the sheet.
    final grabber = find.byWidgetPredicate(
      (w) =>
          w is Container &&
          w.constraints?.maxWidth == 40 &&
          w.constraints?.maxHeight == 4,
    );
    expect(grabber, findsOneWidget);
    expect(tester.getCenter(grabber).dx, closeTo(195, 1));
  });

  testWidgets('height factor is configurable', (tester) async {
    await _open(tester, heightFactor: 0.5);
    expect(
      tester.getSize(find.byType(AppBottomSheet)).height,
      closeTo(844 * 0.5, 1),
    );
  });

  testWidgets('content scrolls; header and actions stay fixed', (tester) async {
    await _open(tester, title: 'Title');
    final headerY = tester.getTopLeft(find.text('Title')).dy;
    final saveY = tester.getTopLeft(find.text('Save')).dy;
    final rowY = tester.getTopLeft(find.text('Row 0')).dy;

    await tester.drag(find.text('Row 3'), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Title')).dy, headerY);
    expect(tester.getTopLeft(find.text('Save')).dy, saveY);
    expect(tester.getTopLeft(find.text('Row 0')).dy, lessThan(rowY));
  });

  testWidgets('title is text only, in the fixed screen-title style', (
    tester,
  ) async {
    await _open(tester, title: 'Choose a size');
    final title = tester.widget<Text>(find.text('Choose a size'));
    expect(title.style?.fontFamily, startsWith('Newsreader'));
    expect(title.style?.fontSize, 24);
    expect(title.maxLines, 1);
    expect(tester.getCenter(find.text('Choose a size')).dx, closeTo(195, 1));
  });

  testWidgets('no title, no title row', (tester) async {
    await _open(tester);
    final grabberBottom = tester
        .getBottomLeft(
          find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.constraints?.maxWidth == 40 &&
                w.constraints?.maxHeight == 4,
          ),
        )
        .dy;
    // Content starts right under the grabber's 20pt gap.
    expect(
      tester.getTopLeft(find.text('Row 0')).dy,
      closeTo(grabberBottom + 20, 1),
    );
  });

  testWidgets('pop returns a value; tapping outside dismisses with null', (
    tester,
  ) async {
    var result = await _open(tester);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(await result, 'saved');

    result = await _open(tester, withActions: false);
    expect(find.text('Save'), findsNothing); // no footer without actions
    await tester.tapAt(const Offset(195, 40)); // the scrim
    await tester.pumpAndSettle();
    expect(find.byType(AppBottomSheet), findsNothing);
    expect(await result, isNull);
  });
}
