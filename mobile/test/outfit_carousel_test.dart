import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/widgets/outfit_carousel.dart';

void main() {
  testWidgets('a swipe snaps to the next card', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: OutfitCarousel(
              children: [
                for (var i = 0; i < 3; i++)
                  Container(key: ValueKey(i), height: 200, color: Colors.brown),
              ],
            ),
          ),
        ),
      ),
    );
    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(scrollable.position.pixels, 0);

    await tester.fling(find.byKey(const ValueKey(0)), const Offset(-150, 0), 800);
    await tester.pumpAndSettle();

    // Card width = 390 - 16 - 16 - 32 = 326, plus the 16 gap.
    expect(scrollable.position.pixels, closeTo(342, 0.5));
  });

  testWidgets('a lone card is full width and does not scroll', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 390,
            child: OutfitCarousel(children: [SizedBox(key: ValueKey('c'), height: 100)]),
          ),
        ),
      ),
    );
    expect(tester.getSize(find.byKey(const ValueKey('c'))).width, 358);
  });
}
