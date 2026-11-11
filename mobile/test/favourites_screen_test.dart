import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/favourites/favourites_providers.dart';
import 'package:mobile/modules/favourites/screens/favourites_screen.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/shared/models/api_error.dart';
import 'package:mobile/shared/widgets/titled_screen_header.dart';

Outfit _outfit(String id, {int worn = 0, String colour = 'black'}) =>
    Outfit.fromJson({
      'id': id,
      'occasion': 'work',
      'items': [
        {
          'item_id': '$id-a',
          'name': 'Wool Blazer',
          'category': 'outerwear',
          'formality': 'smart_casual',
          'color_name': colour,
        },
        {
          'item_id': '$id-b',
          'name': 'Loafers',
          'category': 'shoes',
          'formality': 'smart_casual',
          'color_name': 'camel',
        },
      ],
      'is_favorite': true,
      'worn_count': worn,
    });

WardrobeItem _item(String id, String name, {int worn = 0}) =>
    WardrobeItem.fromJson({
      'id': id,
      'name': name,
      'category': 'tops',
      'worn_count': worn,
      'is_favorite': true,
      'created_at': '2026-11-01T00:00:00Z',
      'updated_at': '2026-11-01T00:00:00Z',
    });

Future<void> _pump(
  WidgetTester tester, {
  List<Outfit> outfits = const [],
  Future<List<WardrobeItem>> Function()? items,
}) async {
  tester.view.physicalSize = const Size(390, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        favouriteOutfitsProvider.overrideWithValue(outfits),
        favouriteItemsProvider.overrideWith(
          (ref) => (items ?? () async => const <WardrobeItem>[])(),
        ),
      ],
      child: const MaterialApp(home: FavouritesScreen()),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('outfits tab: grid, counts and taste insight', (tester) async {
    await _pump(
      tester,
      outfits: [_outfit('o1', worn: 2), _outfit('o2', worn: 1)],
      items: () async => [_item('i1', 'Ribbed Knit')],
    );

    expect(find.text('Favourites'), findsOneWidget);
    // Same header as Notifications: centred title, back arrow, filter, avatar.
    expect(find.byType(TitledScreenHeader), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(tester.getCenter(find.text('Favourites')).dx, closeTo(195, 1));
    // Counts on both tabs; the selected one in a badge.
    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Work look'), findsNWidgets(2));
    expect(find.text('Smart casual · Worn 2 times'), findsOneWidget);
    expect(find.text('Smart casual · Worn 1 time'), findsOneWidget);
    expect(find.text('Wear this'), findsNWidgets(2));
    expect(find.text('We are learning your taste'), findsOneWidget);
    expect(
      find.text('You save smart casual and neutral tones the most.'),
      findsOneWidget,
    );
    // The Stitch design-preview chips are not app UI.
    expect(find.text('Populated'), findsNothing);
  });

  testWidgets('items tab lists saved pieces', (tester) async {
    await _pump(
      tester,
      items: () async => [_item('i1', 'Ribbed Knit', worn: 3)],
    );

    await tester.tap(find.text('Items'));
    await tester.pump();

    expect(find.text('Ribbed Knit'), findsOneWidget);
    expect(find.text('Tops · Worn 3 times'), findsOneWidget);
    expect(find.text('Wear this'), findsNothing);
  });

  testWidgets('empty states per tab', (tester) async {
    await _pump(tester);

    expect(find.text('No saved outfits yet'), findsOneWidget);
    expect(find.text('We are learning your taste'), findsNothing);

    await tester.tap(find.text('Items'));
    await tester.pump();
    expect(find.text('No saved pieces yet'), findsOneWidget);
  });

  testWidgets('items error offers a retry', (tester) async {
    await _pump(
      tester,
      items: () async => throw const ApiException(
        code: 'network',
        message: 'No connection.',
      ),
    );

    await tester.tap(find.text('Items'));
    await tester.pump();
    expect(find.text("Couldn't load your pieces"), findsOneWidget);
    expect(find.text('No connection.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('debug sample cards match the mock and never hit the API', (
    tester,
  ) async {
    await _pump(
      tester,
      outfits: sampleFavouriteOutfits(),
      items: () async => sampleFavouriteItems(),
    );

    for (final (title, line) in const [
      ('Autumn camel & denim', 'Smart casual · Worn 2 times'),
      ('Tailored espresso look', 'Formal · Worn 1 time'),
      ('Rainy-day layers', 'Casual · Never worn'),
      ('Dry office classic', 'Smart casual · Worn 4 times'),
    ]) {
      expect(find.text(title), findsOneWidget, reason: title);
      expect(find.text(line), findsOneWidget, reason: line);
    }
    expect(find.text('4'), findsOneWidget); // Outfits badge
    expect(find.text('6'), findsOneWidget); // Items count

    // Actions on a sample explain themselves instead of calling the API.
    await tester.tap(find.text('Wear this').first);
    await tester.pump();
    expect(
      find.text('Sample card — heart a real outfit or piece to see it here.'),
      findsOneWidget,
    );
  });

  test('taste insight needs two saves and names the leanings', () {
    expect(tasteInsight(outfits: [_outfit('a')], items: const []), isNull);
    expect(
      tasteInsight(
        outfits: [_outfit('a', colour: 'red'), _outfit('b', colour: 'red')],
        items: const [],
      ),
      // red, camel, red, camel → 50% neutral → names the top colour.
      'You save smart casual and red pieces the most.',
    );
  });
}
