import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/log_outfit_result.dart';
import 'package:mobile/modules/today/models/outfit.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/today/widgets/mix_match_sheet.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';
import 'package:mobile/shared/widgets/app_bottom_sheet.dart';
import 'package:mobile/modules/today/day_plans_service.dart';

import 'support/fake_day_plans_service.dart';

/// Records what the sheet sends.
class _Today extends TodayService {
  _Today() : super(Dio());
  final swaps = <List<({String oldItemId, String newItemId})>>[];
  final logged = <String>[];
  final favourited = <String>[];

  @override
  Future<({List<OutfitItem> items, int score})> mixAndMatch(
    String outfitId,
    List<({String oldItemId, String newItemId})> s,
  ) async {
    swaps.add(s);
    return (items: _outfit.items, score: 90);
  }

  @override
  Future<LogOutfitResult> logOutfitWorn(String outfitId) async {
    logged.add(outfitId);
    return LogOutfitResult.fromJson({
      'outfit_id': outfitId,
      'logged_at': '2026-11-11T09:00:00Z',
      'toast': {'message': 'Logged!'},
    });
  }

  @override
  Future<bool> toggleFavorite(String outfitId) async {
    favourited.add(outfitId);
    return true;
  }
}

class _Wardrobe extends WardrobeService {
  _Wardrobe() : super(Dio());

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    WardrobeItem w(String id, String name, String category, String f) =>
        WardrobeItem.fromJson({
          'id': id,
          'name': name,
          'category': category,
          'formality': f,
          'created_at': '2026-11-01T00:00:00Z',
          'updated_at': '2026-11-01T00:00:00Z',
        });
    return WardrobeListResult(
      items: [
        w('coat', 'Camel Coat', 'outerwear', 'smart_casual'), // in outfit
        w('blazer', 'Wool Blazer', 'outerwear', 'smart_casual'),
        w('denim', 'Denim Jacket', 'outerwear', 'casual'),
        w('knit', 'Ribbed Knit', 'tops', 'smart_casual'),
      ],
      total: 4,
      limit: limit,
      offset: offset,
    );
  }
}

final _outfit = Outfit.fromJson({
  'id': 'o1',
  'occasion': 'work',
  'items': [
    {
      'item_id': 'coat',
      'name': 'Camel Coat',
      'category': 'outerwear',
      'formality': 'smart_casual',
    },
    {
      'item_id': 'tee',
      'name': 'White Tee',
      'category': 'tops',
      'formality': 'smart_casual',
    },
    {
      'item_id': 'trousers',
      'name': 'Charcoal Trousers',
      'category': 'bottoms',
      'formality': 'smart_casual',
    },
  ],
});

Future<_Today> _open(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final today = _Today();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        todayServiceProvider.overrideWithValue(today),
        wardrobeServiceProvider.overrideWithValue(_Wardrobe()),
        dayPlansServiceProvider.overrideWithValue(FakeDayPlansService()),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => MixMatchSheet.show(context, _outfit),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return today;
}

void main() {
  testWidgets('shows the mock layout for the outfit', (tester) async {
    await _open(tester);

    // Built on the shared sheet: default 80% tall, text title, no close button.
    expect(find.byType(AppBottomSheet), findsOneWidget);
    expect(
      tester.getSize(find.byType(AppBottomSheet)).height,
      closeTo(844 * 0.8, 1),
    );
    expect(find.byIcon(Icons.close), findsNothing);

    expect(find.text('Mix & match'), findsOneWidget);
    expect(find.text('Reset'), findsOneWidget);
    expect(find.text('For: Work · Smart casual'), findsOneWidget);
    expect(find.text('Works for smart casual'), findsOneWidget);
    for (final s in ['Layer', 'Top', 'Bottom', 'Shoes', 'Extra']) {
      expect(find.text(s), findsOneWidget, reason: s);
    }
    // Layer slot: the outfit's coat + two other outerwear pieces.
    expect(find.text('Layer · 3 options · Swapping is free'), findsOneWidget);
    expect(find.text('None'), findsOneWidget);
    expect(find.text('Wool Blazer'), findsOneWidget);
    expect(find.text('Best fit'), findsNWidgets(2)); // coat + blazer
    await tester.ensureVisible(find.text('Add more in Wardrobe'));
    await tester.pumpAndSettle();
    expect(find.text('Add more in Wardrobe'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Wear this'), findsOneWidget);
  });

  testWidgets('swaps are previewed, then sent once with Wear this', (
    tester,
  ) async {
    final today = await _open(tester);

    // The grid sits below the preview + tabs: scroll the sheet down to it.
    await tester.ensureVisible(find.text('Denim Jacket'));
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Denim Jacket'));
    await tester.pump();
    // Casual piece in a smart-casual look → the fit line warns.
    expect(
      find.text('Denim Jacket is more casual than the rest'),
      findsOneWidget,
    );
    expect(today.swaps, isEmpty); // nothing sent yet

    await tester.tap(find.text('Wear this'));
    await tester.pumpAndSettle();

    expect(today.swaps, [
      [(oldItemId: 'coat', newItemId: 'denim')],
    ]);
    expect(today.logged, ['o1']);
    expect(find.text('Mix & match'), findsNothing); // closed
    expect(find.text('Logged!'), findsOneWidget);
  });

  testWidgets('Reset puts the picks back; no change sends no swap', (
    tester,
  ) async {
    final today = await _open(tester);

    await tester.ensureVisible(find.text('Wool Blazer'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Wool Blazer'));
    await tester.pump();
    await tester.tap(find.text('Reset'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(today.swaps, isEmpty);
    expect(today.favourited, ['o1']);
    expect(find.text('Saved to favourites'), findsOneWidget);
  });

  testWidgets('None and empty slots explain they are coming', (tester) async {
    await _open(tester);

    await tester.ensureVisible(find.text('None'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('None'));
    await tester.pump();
    expect(find.text('Removing a piece is coming soon.'), findsOneWidget);

    await tester.ensureVisible(find.text('Shoes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shoes'));
    await tester.pump();
    expect(find.text('Shoes · 0 options · Swapping is free'), findsOneWidget);
  });
}
