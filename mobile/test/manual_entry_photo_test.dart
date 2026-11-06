import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:mobile/modules/wardrobe/image_pick.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_mutations.dart';
import 'package:mobile/modules/wardrobe/screens/manual_entry_screen.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';

/// Records the create and photo calls; everything else is empty.
class _FakeWardrobeService extends WardrobeService {
  _FakeWardrobeService() : super(Dio());

  WardrobeItemInput? created;
  String? photosFor;
  int photos = 0;

  WardrobeItem _item(String name) => WardrobeItem.fromJson({
    'id': 'new-item',
    'name': name,
    'category': 'tops',
    'created_at': '2026-11-06T00:00:00Z',
    'updated_at': '2026-11-06T00:00:00Z',
  });

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async => WardrobeListResult(
    items: const [],
    total: 0,
    limit: limit,
    offset: offset,
  );

  @override
  Future<WardrobeItem> createItem(WardrobeItemInput input) async {
    created = input;
    return _item(input.name ?? '');
  }

  @override
  Future<WardrobeItem> addImages(
    String itemId,
    List<PickedImage> images,
  ) async {
    photosFor = itemId;
    photos += images.length;
    return _item(created?.name ?? '');
  }
}

void main() {
  const picker = MethodChannel('plugins.flutter.io/image_picker');

  testWidgets('a new item’s photo is picked up front and saved with it', (
    tester,
  ) async {
    // A real (tiny) photo for the library to hand back.
    final photo = await tester.runAsync(() async {
      final dir = await Directory.systemTemp.createTemp('manual_entry');
      final file = File('${dir.path}/shirt.jpg');
      await file.writeAsBytes(img.encodeJpg(img.Image(width: 40, height: 40)));
      return file;
    });
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      picker,
      (call) async => photo!.path,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        picker,
        null,
      ),
    );

    tester.view.physicalSize = const Size(390 * 3, 844 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final service = _FakeWardrobeService();
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('wardrobe')),
          routes: [
            GoRoute(path: 'add', builder: (_, _) => const ManualEntryScreen()),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          wardrobeServiceProvider.overrideWithValue(service),
          wardrobeCapacityProvider.overrideWith(
            (ref) async =>
                const WardrobeCapacity(used: 0, isPro: false, visibleTotal: 0),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // The tile offers a photo now, not "after saving".
    expect(find.text('PHOTO AFTER SAVING'), findsNothing);
    await tester.tap(find.text('ADD PHOTO'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Library'));
    // The sheet closes, then the photo is read and shrunk: real work, off
    // the fake clock, so give it real time until the preview shows.
    for (var i = 0; i < 20 && find.text('CHANGE').evaluate().isEmpty; i++) {
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
    await tester.pumpAndSettle();
    expect(find.text('CHANGE'), findsOneWidget); // the preview is up

    await tester.enterText(find.byType(TextField).first, 'Linen Shirt');
    await tester.tap(find.text('Add to Wardrobe'));
    await tester.pumpAndSettle();

    expect(service.created?.name, 'Linen Shirt');
    expect(service.photosFor, 'new-item');
    expect(service.photos, 1);
    expect(find.text('wardrobe'), findsOneWidget); // back on the wardrobe
  });
}
