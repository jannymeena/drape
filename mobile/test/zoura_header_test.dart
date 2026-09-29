import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/zoura_header.dart';

Widget _host(Widget child) =>
    MaterialApp(home: Scaffold(body: Column(children: [child])));

void main() {
  testWidgets('nested header: wordmark line, back, title, action', (t) async {
    var backs = 0;
    var shares = 0;
    await t.pumpWidget(_host(NestedHeader(
      title: 'Wishlist',
      onBack: () => backs++,
      action: IconButton(
          icon: const Icon(Icons.ios_share), onPressed: () => shares++),
    )));

    expect(find.text('ZOURA'), findsOneWidget);
    expect(find.text('Wishlist'), findsOneWidget);
    await t.tap(find.byIcon(Icons.arrow_back));
    await t.tap(find.byIcon(Icons.ios_share));
    expect((backs, shares), (1, 1));
  });

  testWidgets('wordmark sits at the same spot with or without tab actions',
      (t) async {
    await t.pumpWidget(_host(const ZouraTopBar()));
    final bare = t.getTopLeft(find.text('ZOURA'));
    await t.pumpWidget(_host(ZouraTopBar(actions: [
      IconButton(icon: const Icon(Icons.add), onPressed: () {}),
    ])));
    expect(t.getTopLeft(find.text('ZOURA')), bare);
  });

  testWidgets('close variant swaps the back icon', (t) async {
    await t.pumpWidget(_host(NestedHeader(
      title: 'Cancel Subscription',
      onBack: () {},
      backIcon: Icons.close,
    )));
    expect(find.byIcon(Icons.close), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });
}
