import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/shop/models/shop.dart';
import 'package:mobile/modules/shop/screens/ai_advisor_conversation_screen.dart';
import 'package:mobile/modules/shop/shop_service.dart';
import 'package:mobile/shared/models/api_error.dart';

Map<String, dynamic> _item(String id, String name, int cents) => {
      'product_id': id,
      'name': name,
      'brand': 'Brand $id',
      'category': 'tops',
      'price_cents': cents,
      'currency': 'CAD',
      'image_url': '',
      'product_url': 'https://www.awin1.com/$id',
      'retailer': 'Shop',
    };

final _convo = AdvisorConversation.fromJson({
  'id': 'c1',
  'title': 'Tamil wedding',
  'updated_at': '2026-09-30T00:00:00Z',
  'messages': [
    {'role': 'user', 'content': 'Tamil wedding as a guest?'},
    {
      'role': 'assistant',
      'content': 'Rich jewel tones.',
      'looks': [
        {
          'name': 'Classic Guest',
          'note': 'Pairs with your navy blazer.',
          'total_price_cents': 16500,
          'items': [_item('p1', 'Silk Kurta', 12000), _item('p2', 'Chinos', 4500)],
        },
        {
          'name': 'Modern Minimalist',
          'note': '',
          'total_price_cents': 15500,
          'items': [_item('p3', 'Linen Shirt', 15500)],
        },
      ],
    },
  ],
});

class _Service extends ShopService {
  _Service({this.limitReached = false}) : super(Dio());
  final bool limitReached;

  @override
  Future<AdvisorConversation> advisorConversation(String id) async => _convo;

  @override
  Future<AdvisorConversation> advisorAsk(String question,
      {String? conversationId}) async {
    if (limitReached) {
      throw const ApiException(
          code: 'limit_reached', statusCode: 429, message: 'Weekly limit reached');
    }
    return _convo;
  }

  @override
  Future<ShopFeed> getFeed() async =>
      const ShopFeed(products: [], measurementsComplete: false);
}

Future<void> _pump(WidgetTester tester, _Service service,
    {String? id, String? question}) async {
  tester.view.physicalSize = const Size(1080, 4000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: [shopServiceProvider.overrideWithValue(service)],
    child: MaterialApp(
      home: AiAdvisorConversationScreen(conversationId: id, question: question),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opens a saved conversation: first look expanded with Buy pills',
      (tester) async {
    await _pump(tester, _Service(), id: 'c1');

    expect(find.text('Rich jewel tones.'), findsOneWidget);
    expect(find.text('LOOK 1 OF 2'), findsOneWidget);
    expect(find.text('Classic Guest'), findsOneWidget);
    expect(find.text('~\$165'), findsOneWidget);
    expect(find.text('Silk Kurta'), findsOneWidget);
    expect(find.text('\$120'), findsOneWidget);
    expect(find.text('Pairs with your navy blazer.'), findsOneWidget);
    expect(find.text('BUY'), findsNWidgets(2));
    // Measurements incomplete -> the Update strip shows.
    expect(find.text('Update →'), findsOneWidget);

    // Look 2 is a collapsed row until tapped.
    expect(find.text('Linen Shirt'), findsNothing);
    await tester.tap(find.text('Modern Minimalist'));
    await tester.pumpAndSettle();
    expect(find.text('LOOK 2 OF 2'), findsOneWidget);
    expect(find.text('Linen Shirt'), findsOneWidget);
    expect(find.text('Silk Kurta'), findsNothing);
  });

  testWidgets('weekly limit swaps the input for the upgrade card',
      (tester) async {
    await _pump(tester, _Service(limitReached: true), question: 'Date night?');

    expect(find.text('Unlock Unlimited Styling Advice'), findsOneWidget);
    expect(find.text('Upgrade to Pro'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });
}
