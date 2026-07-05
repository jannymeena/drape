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

  test('AdvisorConversation parses messages with suggestions', () {
    final convo = AdvisorConversation.fromJson({
      'id': 'c1',
      'title': 'Summer wedding',
      'updated_at': '2026-07-05T00:00:00Z',
      'messages': [
        {'role': 'user', 'content': 'What do I wear?'},
        {
          'role': 'assistant',
          'content': 'Linen layers.',
          'suggestions': [
            {
              'name': 'Linen shirt',
              'category': 'tops',
              'reason': 'Breathable.',
              'product_id': 'p1',
            },
          ],
        },
      ],
    });
    expect(convo.messages, hasLength(2));
    expect(convo.messages.last.suggestions.single.productId, 'p1');
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
