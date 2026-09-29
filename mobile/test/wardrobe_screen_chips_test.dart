import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_mutations.dart';
import 'package:mobile/modules/wardrobe/screens/wardrobe_screen.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';

/// Switching chips only changes the grid area: the starter ("unlock wardrobe
/// mode") banner and the grow card stay put — on Favorites too, and while
/// the new chip is still loading.
class _Service extends WardrobeService {
  _Service() : super(Dio());

  final gates = <String, Completer<void>>{};
  final starter = [
    for (var i = 0; i < 3; i++)
      WardrobeItem(
        id: 's$i',
        name: 'Starter $i',
        category: 'tops',
        wornCount: 0,
        isFavorite: false,
        isStarterWardrobe: true,
        addedVia: 'starter_seed',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
  ];

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    final key = isFavorite == true ? 'favorites' : (category ?? 'all');
    await gates[key]?.future;
    final items = key == 'all' ? starter : const <WardrobeItem>[];
    return WardrobeListResult(items: items, total: items.length, limit: limit, offset: offset);
  }
}

void main() {
  testWidgets('banners and the grow card survive a switch to Favorites',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final service = _Service();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        wardrobeServiceProvider.overrideWithValue(service),
        wardrobeCapacityProvider.overrideWith(
          (_) async => const WardrobeCapacity(used: 0, isPro: false, visibleTotal: 3),
        ),
      ],
      child: const MaterialApp(home: WardrobeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Add Your First Item'), findsOneWidget);
    expect(find.text('Grow Your Wardrobe'), findsOneWidget);

    service.gates['favorites'] = Completer<void>();
    await tester.tap(find.text('Favorites'));
    await tester.pump();
    // Favorites still loading: only the grid area changed.
    expect(find.text('Add Your First Item'), findsOneWidget);
    expect(find.text('Grow Your Wardrobe'), findsOneWidget);
    expect(find.text('No favorites yet'), findsNothing);

    service.gates['favorites']!.complete();
    await tester.pumpAndSettle();
    expect(find.text('No favorites yet'), findsOneWidget);
    expect(find.text('Add Your First Item'), findsOneWidget);
    expect(find.text('Grow Your Wardrobe'), findsOneWidget);
  });
}
