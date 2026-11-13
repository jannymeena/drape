import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/widgets/outfit_collage.dart';
import 'package:mobile/shared/widgets/buy_pill.dart';
import 'package:mobile/shared/widgets/garment_placeholder.dart';

const _coat = GarmentCell(
  cutoutUrl: 'http://img/coat.webp',
  cutoutBox: [0.04, 0.2, 0.92, 0.6],
  priority: 900,
  category: 'outerwear',
);
const _shoes = GarmentCell(
  cutoutUrl: 'http://img/shoes.webp',
  cutoutBox: [0.1, 0.3, 0.8, 0.4],
  priority: 400,
  category: 'shoes',
);
const _shopShirt = GarmentCell(
  imageUrl: 'http://img/shirt.jpg',
  priority: 600,
  category: 'tops',
  buyUrl: 'https://shop.example/shirt',
);
const _noPhoto = GarmentCell(priority: 100, category: 'jewelry');

Future<void> _pump(WidgetTester tester, List<GarmentCell> cells) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: OutfitCollage(cells: cells, seed: 'outfit-1'),
        ),
      ),
    ),
  );
  await tester.pump();
}

Finder _network(String url) =>
    find.byWidgetPredicate((w) => w is CachedNetworkImage && w.imageUrl == url);

void main() {
  testWidgets('pieces lie on one of the bundled surfaces', (tester) async {
    await _pump(tester, const [_coat, _shoes]);
    final background = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          w.image is AssetImage &&
          (w.image as AssetImage).assetName.startsWith(
            'assets/outfit_backgrounds/',
          ),
    );
    expect(background, findsOneWidget);
  });

  testWidgets('cut-outs get a shadow and are sized by priority', (
    tester,
  ) async {
    await _pump(tester, const [_shoes, _coat]);

    // Each cut-out: the piece plus its shadow (the same image, darkened).
    expect(_network('http://img/coat.webp'), findsNWidgets(2));
    expect(_network('http://img/shoes.webp'), findsNWidgets(2));

    // The coat (900) gets the bigger slot than the shoes (400), so its
    // piece — the square's width × its box width — is drawn bigger.
    double pieceWidth(String url, double boxWidth) =>
        tester.getSize(_network(url).first).width * boxWidth;
    expect(
      pieceWidth('http://img/coat.webp', 0.92),
      greaterThan(pieceWidth('http://img/shoes.webp', 0.8)),
    );
  });

  testWidgets('no cut-out: the plain photo, unframed; a shop piece: Buy pill', (
    tester,
  ) async {
    await _pump(tester, const [_coat, _shopShirt, _noPhoto]);

    expect(_network('http://img/shirt.jpg'), findsOneWidget);
    // Fitted whole, no frame (no white-edged card round it).
    final shirt = tester.widget<CachedNetworkImage>(
      _network('http://img/shirt.jpg'),
    );
    expect(shirt.fit, BoxFit.contain);
    expect(
      find.ancestor(
        of: _network('http://img/shirt.jpg'),
        matching: find.byType(DecoratedBox),
      ),
      findsNothing,
    );
    expect(find.byType(BuyPill), findsOneWidget);
    // No photo at all: the drawn placeholder.
    expect(find.byType(GarmentPlaceholder), findsOneWidget);
  });

  testWidgets('nothing is tilted', (tester) async {
    await _pump(tester, const [_coat, _shoes, _shopShirt]);
    final turned = find.descendant(
      of: find.byType(OutfitCollage),
      matching: find.byWidgetPredicate(
        (w) => w is Transform && !w.transform.getRotation().isIdentity(),
      ),
    );
    expect(find.byWidgetPredicate((w) => w is RotatedBox), findsNothing);
    expect(turned, findsNothing);
  });

  testWidgets('the same outfit is laid out the same way every time', (
    tester,
  ) async {
    await _pump(tester, const [_coat, _shoes, _shopShirt]);
    final first = tester.getRect(_network('http://img/coat.webp').last);

    await tester.pumpWidget(const SizedBox());
    await _pump(tester, const [_coat, _shoes, _shopShirt]);
    expect(tester.getRect(_network('http://img/coat.webp').last), first);
  });

  test('outfit items read the cut-out and priority from the API', () {
    final item = OutfitItem.fromJson({
      'item_id': 'i1',
      'name': 'Trench',
      'category': 'outerwear',
      'cutout_url': 'http://img/coat.webp',
      'cutout_box': [0.04, 0.2, 0.92, 0.6],
      'dress_priority': 900,
    });
    expect(item.cutoutUrl, 'http://img/coat.webp');
    expect(item.cutoutBox, [0.04, 0.2, 0.92, 0.6]);
    expect(item.dressPriority, 900);

    // Round-trips through the dashboard cache.
    final again = OutfitItem.fromJson(item.toJson());
    expect(again.cutoutBox, item.cutoutBox);
    expect(again.dressPriority, 900);

    // Older payloads: no cut-out, the middle priority.
    final old = OutfitItem.fromJson({
      'item_id': 'i2',
      'name': 'Tee',
      'category': 'tops',
      'cutout_box': [1, 2],
    });
    expect(old.cutoutUrl, isNull);
    expect(old.cutoutBox, isNull);
    expect(old.dressPriority, OutfitItem.defaultDressPriority);
  });
}
