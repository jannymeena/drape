import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/widgets/outfit_card.dart';
import 'package:mobile/modules/today/widgets/outfit_item_grid.dart';
import 'package:mobile/shared/widgets/buy_pill.dart';

/// AWIN products in outfits: the parsed product fields, the occasion heading,
/// the "Buy" pill on unowned pieces and "Shop the look" replacing "Wear this".
void main() {
  Map<String, dynamic> outfitJson({bool withShopItem = true}) => {
        'id': 'out-1',
        'user_id': 'u-1',
        'occasion': 'date_night',
        'items': [
          {'item_id': 'i-1', 'name': 'My jeans', 'category': 'bottoms'},
          if (withShopItem)
            {
              'item_id': 'p-1',
              'name': 'Satin Cami',
              'category': 'tops',
              'product_id': 'p-1',
              'product_url': 'https://www.awin1.com/pclick.php?p=1',
              'price_cents': 2400,
              'currency': 'USD',
              'retailer': 'boohoo (US & Canada)',
            },
        ],
        'using_starter_wardrobe': false,
        'is_logged': false,
        'worn_count': 0,
        if (withShopItem) 'shop_the_look': true,
      };

  test('parses product fields, price label and shop-the-look', () {
    final outfit = Outfit.fromJson(outfitJson());
    final shop = outfit.items.last;
    expect(shop.isShopItem, isTrue);
    expect(shop.priceLabel, r'US$24.00');
    expect(outfit.items.first.isShopItem, isFalse);
    expect(outfit.shopTheLook, isTrue);
    expect(outfit.occasionHeading, 'For date night');
    // Round-trips through the dashboard cache.
    expect(Outfit.fromJson(outfit.toJson()).items.last.productUrl, shop.productUrl);
  });

  test('an all-owned outfit is not shop-the-look', () {
    expect(Outfit.fromJson(outfitJson(withShopItem: false)).shopTheLook, isFalse);
  });

  Future<void> pumpCard(WidgetTester tester, {required bool shop, bool logged = false}) {
    return tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: OutfitCard(
            outfit: OutfitCardData(
              id: 'out-1',
              heading: 'For work',
              items: [
                const GarmentCell(category: 'tops'),
                GarmentCell(category: 'bottoms', buyUrl: shop ? 'https://www.awin1.com/x' : null),
              ],
              reasoning: 'Sharp.',
              shopTheLook: shop,
              logged: logged,
            ),
          ),
        ),
      ),
    ));
  }

  testWidgets('shop pieces get a Buy pill and the card offers Shop the look', (tester) async {
    await pumpCard(tester, shop: true);
    expect(find.text('For work'), findsOneWidget);
    expect(find.byType(BuyPill), findsOneWidget);
    expect(find.text('SHOP THE LOOK'), findsOneWidget);
    expect(find.text('WEAR THIS'), findsNothing);
  });

  testWidgets('owned outfits offer Wear this, then Worn today', (tester) async {
    await pumpCard(tester, shop: false);
    expect(find.byType(BuyPill), findsNothing);
    expect(find.text('WEAR THIS'), findsOneWidget);
    await pumpCard(tester, shop: false, logged: true);
    expect(find.text('WORN TODAY'), findsOneWidget);
  });
}
