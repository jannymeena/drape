import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/widgets/drape_bottom_nav.dart';

void main() {
  testWidgets('five tabs, Stylist in the middle', (tester) async {
    DrapeNavDestination? tapped;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: DrapeBottomNav(
            current: DrapeNavDestination.today,
            onSelected: (d) => tapped = d,
          ),
        ),
      ),
    );

    final labels = ['TODAY', 'WARDROBE', 'STYLIST', 'SHOP', 'PROFILE'];
    final xs = [
      for (final l in labels) tester.getCenter(find.text(l)).dx,
    ];
    expect(xs, orderedEquals([...xs]..sort()), reason: 'left-to-right order');
    // The enum order is the shell's branch order.
    expect(DrapeNavDestination.values.map((d) => d.name),
        ['today', 'wardrobe', 'stylist', 'shop', 'profile']);

    await tester.tap(find.text('STYLIST'));
    expect(tapped, DrapeNavDestination.stylist);
  });
}
