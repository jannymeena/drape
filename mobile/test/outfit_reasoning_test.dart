import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit_reasoning.dart';

/// Parses a representative `GET /outfits/{id}/reasoning` payload (shape from
/// `OutfitReasoningResponse`) so a backend field rename is caught here.
void main() {
  test('OutfitReasoning parses narrative, items, score, label, factors', () {
    final r = OutfitReasoning.fromJson({
      'outfit_id': 'out-1',
      'full_text': 'This look balances a cool top against warm trousers.',
      'items': [
        {
          'item_id': 'i1',
          'name': 'Navy Linen Shirt',
          'why_it_works': 'Cool undertone complements your palette.',
          'image_url': 'https://example.com/shirt.jpg',
        },
        {
          'item_id': 'i2',
          'name': 'Terracotta Trousers',
          'why_it_works': null,
          'image_url': null,
        },
      ],
      'compatibility_score': 87,
      'compatibility_label': 'High compatibility',
      'factors': ['Color harmony', 'Occasion appropriateness'],
    });

    expect(r.outfitId, 'out-1');
    expect(r.fullText, contains('balances'));
    expect(r.items, hasLength(2));
    expect(r.items.first.name, 'Navy Linen Shirt');
    expect(r.items[1].whyItWorks, isNull);
    expect(r.items[1].imageUrl, isNull);
    expect(r.compatibilityScore, 87);
    expect(r.compatibilityLabel, 'High compatibility');
    expect(r.factors, ['Color harmony', 'Occasion appropriateness']);
  });

  test('tolerates a null narrative / score and missing collections', () {
    final r = OutfitReasoning.fromJson({
      'outfit_id': 'out-2',
      'full_text': null,
      'items': <dynamic>[],
      'compatibility_score': null,
      'compatibility_label': 'Could be better',
      'factors': <dynamic>[],
    });

    expect(r.fullText, isNull);
    expect(r.compatibilityScore, isNull);
    expect(r.items, isEmpty);
    expect(r.factors, isEmpty);
  });
}
