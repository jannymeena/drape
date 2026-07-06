import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/widgets/wardrobe_empty_state.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  testWidgets('WardrobeEmptyState shows the designed copy and fires onAdd',
      (tester) async {
    var added = false;
    await tester
        .pumpWidget(_wrap(WardrobeEmptyState(onAdd: () => added = true)));

    expect(find.text('Your digital wardrobe awaits'), findsOneWidget);
    expect(find.text('AI outfits from your real wardrobe'), findsOneWidget);
    expect(find.text('Cost-per-wear tracking'), findsOneWidget);
    expect(find.text('Never forget what you own'), findsOneWidget);

    await tester.tap(find.text('+ Add Your First Item'));
    expect(added, isTrue);
  });

  testWidgets(
      'FavoritesEmptyState shows the designed copy and the style-inspiration '
      'card fires onExplore', (tester) async {
    var explored = false;
    await tester.pumpWidget(
      _wrap(FavoritesEmptyState(onExplore: () => explored = true)),
    );

    expect(find.text('No favorites yet'), findsOneWidget);
    expect(
      find.text('Tap the star on any item to save it here for quick access.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.star), findsOneWidget);
    expect(find.text('STYLE INSPIRATION'), findsOneWidget);
    expect(find.text('Discover new essentials'), findsOneWidget);

    await tester.tap(find.text('Discover new essentials'));
    expect(explored, isTrue);
  });
}
