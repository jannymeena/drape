import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/widgets/add_to_wardrobe_chooser.dart';

/// Regression for the "Add New Item" sheet: the chooser is itself a [ListView],
/// so it must render inside a bounded scrollable host (the DraggableScrollableSheet
/// drives it via [controller]) WITHOUT being wrapped in another scroll view —
/// otherwise the inner list gets unbounded height and throws on open.
void main() {
  testWidgets('renders in a bounded sheet host and reports the tapped choice',
      (tester) async {
    AddToWardrobeChoice? picked;
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        // Mirrors `_openAddSheet`: a bounded Column with the chooser in an
        // Expanded, driven by the sheet's scroll controller.
        body: Column(
          children: [
            Expanded(
              child: AddToWardrobeChooser(
                controller: controller,
                onChoice: (c) => picked = c,
              ),
            ),
          ],
        ),
      ),
    ));

    // No "Vertical viewport was given unbounded height" exception on build.
    expect(tester.takeException(), isNull);
    expect(find.text('Upload Photos'), findsOneWidget);
    expect(find.text('Scan New Item'), findsOneWidget);
    expect(find.text('Add Manually'), findsOneWidget);

    await tester.tap(find.text('Scan New Item'));
    expect(picked, AddToWardrobeChoice.scan);
  });
}
