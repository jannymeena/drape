import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/screens/scanner_screen.dart';

/// The scan review lets the user fix each AI-detected attribute through a
/// bottom-sheet picker whose options are the backend literals.
void main() {
  /// Opens the picker for [field]; the sheet's result lands in the returned
  /// list once it closes (empty list = still open, `[null]` = dismissed).
  Future<List<String?>> openPicker(
    WidgetTester tester, {
    required ScanField field,
    required String current,
  }) async {
    final results = <String?>[];
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async => results.add(await showScanFieldPicker(
                context,
                field: field,
                current: current)),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return results;
  }

  testWidgets('picking an option returns its backend value', (tester) async {
    final results =
        await openPicker(tester, field: ScanField.formality, current: 'casual');
    await tester.tap(find.text('Smart Casual'));
    await tester.pumpAndSettle();
    expect(results, ['smart_casual']);
  });

  testWidgets('colour keeps the AI colour selectable and accepts typed text',
      (tester) async {
    final results =
        await openPicker(tester, field: ScanField.color, current: 'Burgundy');
    expect(find.text('Burgundy'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Teal ');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(results, ['teal']);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    final results =
        await openPicker(tester, field: ScanField.pattern, current: 'solid');
    expect(find.text('PATTERN'), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // the barrier above the sheet
    await tester.pumpAndSettle();
    expect(find.text('PATTERN'), findsNothing);
    expect(results, [null]);
  });

  test('options are the backend literals', () {
    expect(ScanField.category.options, [
      'tops', 'bottoms', 'dresses', 'outerwear', 'shoes', 'accessories', //
      'bags', 'jewelry',
    ]);
    expect(ScanField.pattern.options, [
      'solid', 'striped', 'plaid', 'floral', 'graphic', 'abstract', 'other',
    ]);
    expect(ScanField.formality.options, ['casual', 'smart_casual', 'formal']);
    expect(ScanField.formality.display('smart_casual'), 'Smart Casual');
  });
}
