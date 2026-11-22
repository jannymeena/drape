import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/wardrobe_backgrounds.dart';

void main() {
  const backgrounds = [
    'assets/wardrobe_backgrounds/beige_wall.jpg',
    'assets/wardrobe_backgrounds/studio_grey.jpg',
  ];

  test('an item always gets the same background', () {
    final first = wardrobeBackgroundFor('item-1', backgrounds);
    expect(wardrobeBackgroundFor('item-1', backgrounds), first);
    expect(backgrounds, contains(first));
  });

  test('items are spread across the backgrounds', () {
    final picked = {
      for (var i = 0; i < 40; i++) wardrobeBackgroundFor('item-$i', backgrounds),
    };
    expect(picked, backgrounds.toSet());
  });

  test('no background when there are none', () {
    expect(wardrobeBackgroundFor('item-1', const []), isNull);
  });

  test('for now every item gets the grey studio, never the beige wall', () {
    for (var i = 0; i < 20; i++) {
      expect(
        wardrobeBackgroundFor('item-$i'),
        'assets/wardrobe_backgrounds/studio_grey.jpg',
      );
    }
  });
}
