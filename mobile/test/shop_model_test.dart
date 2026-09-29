import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/shop/models/shop.dart';

void main() {
  test('ShopFeed parses products and the measurements gate', () {
    final feed = ShopFeed.fromJson({
      'products': [
        {
          'id': 'p1',
          'name': 'White Linen Shirt',
          'brand': 'Everlane',
          'category': 'tops',
          'price_cents': 6800,
          'currency': 'CAD',
          'image_url': 'https://cdn/x.jpg',
          'product_url': 'https://shop/x',
          'retailer': 'Everlane',
        },
      ],
      'measurements_complete': false,
    });
    expect(feed.products.single.priceLabel, r'$68.00');
    expect(feed.measurementsComplete, isFalse);
  });

  test('AdvisorConversation parses looks with real products', () {
    final convo = AdvisorConversation.fromJson({
      'id': 'c1',
      'title': 'Summer wedding',
      'updated_at': '2026-07-05T00:00:00Z',
      'messages': [
        {'role': 'user', 'content': 'What do I wear?'},
        {
          'role': 'assistant',
          'content': 'Linen layers.',
          'looks': [
            {
              'name': 'Garden Party',
              'note': 'Pairs with your navy chinos.',
              'total_price_cents': 26300,
              'items': [
                {
                  'product_id': 'p1',
                  'name': 'White Linen Shirt',
                  'brand': 'Everlane',
                  'category': 'tops',
                  'price_cents': 6800,
                  'currency': 'CAD',
                  'image_url': 'https://img/1.jpg',
                  'product_url': 'https://www.awin1.com/p1',
                  'retailer': 'Everlane',
                },
              ],
            },
          ],
        },
      ],
    });
    final look = convo.messages.last.looks.single;
    expect(look.totalLabel, '~\$263');
    expect(look.items.single.priceLabel, '\$68');
    expect(look.items.single.productUrl, 'https://www.awin1.com/p1');
  });

  test('AdvisorMessage from before looks existed parses with no looks', () {
    final m = AdvisorMessage.fromJson({
      'role': 'assistant',
      'content': 'Old answer',
      'suggestions': [
        {'name': 'Shirt', 'category': 'tops', 'reason': 'r'},
      ],
    });
    expect(m.content, 'Old answer');
    expect(m.looks, isEmpty);
  });

  test('BuyDontBuyVerdict parses and classifies', () {
    final verdict = BuyDontBuyVerdict.fromJson({
      'id': 'b1',
      'verdict': 'dont_buy',
      'score': 34,
      'fit_reason': 'Boxy.',
      'value_reason': 'Pricey.',
      'gap_reason': 'Redundant.',
      'created_at': '2026-07-05T00:00:00Z',
      'product_name': null,
    });
    expect(verdict.isBuy, isFalse);
    expect(verdict.score, 34);
  });

  test('WishlistEntry surfaces price drops', () {
    final entry = WishlistEntry.fromJson({
      'product': {
        'id': 'p1',
        'name': 'Camel Overcoat',
        'brand': 'COS',
        'category': 'outerwear',
        'price_cents': 29000,
        'currency': 'CAD',
        'image_url': '',
        'product_url': '',
        'retailer': 'COS',
      },
      'added_price_cents': 29000,
      'current_price_cents': 23200,
      'price_drop_cents': 5800,
      'added_at': '2026-07-05T00:00:00Z',
    });
    expect(entry.hasDrop, isTrue);
    expect(entry.priceDropCents, 5800);
  });

  test('GapAnalysis parses the teaser shape', () {
    final gaps = GapAnalysis.fromJson({
      'gaps': [
        {
          'category': 'bottoms',
          'have': 0,
          'recommended': 4,
          'reason': 'You have 0 bottoms.',
          'outfits_unlocked': 4,
        },
      ],
      'is_teaser': true,
      'pro_teaser': '3 more gaps found.',
    });
    expect(gaps.isTeaser, isTrue);
    expect(gaps.gaps.single.outfitsUnlocked, 4);
  });
}
