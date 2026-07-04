import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/image_pick.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_mutations.dart';
import 'package:mobile/modules/wardrobe/wardrobe_controller.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';
import 'package:mobile/shared/models/api_error.dart';

/// A wardrobe service with canned, call-recording responses so the controller's
/// filter / search / paging / mutation logic can be tested without Dio.
class _FakeWardrobeService extends WardrobeService {
  _FakeWardrobeService() : super(Dio());

  String? lastCategory;
  bool? lastIsFavorite;
  int lastOffset = -1;
  int totalToReport = 0;
  List<WardrobeItem> Function(int offset)? pageBuilder;

  // Mutation knobs.
  ToggleFavoriteResult? favoriteResult;
  ApiException? favoriteError;
  LogWornResult? logResult;
  WardrobeItem? createdResult;
  WardrobeItem? addImagesResult;
  int addImagesCalls = 0;
  int createCalls = 0;
  int? create429AfterNthSuccess; // throw 429 once this many are already created
  String? deletedId;

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    lastCategory = category;
    lastIsFavorite = isFavorite;
    lastOffset = offset;
    final items = pageBuilder?.call(offset) ?? const <WardrobeItem>[];
    return WardrobeListResult(
      items: items,
      total: totalToReport,
      limit: limit,
      offset: offset,
    );
  }

  @override
  Future<ToggleFavoriteResult> toggleFavorite(String itemId) async {
    if (favoriteError != null) throw favoriteError!;
    return favoriteResult!;
  }

  @override
  Future<LogWornResult> logWorn(String itemId, {DateTime? wornDate}) async =>
      logResult!;

  @override
  Future<WardrobeItem> createItem(WardrobeItemInput input) async {
    if (create429AfterNthSuccess != null &&
        createCalls >= create429AfterNthSuccess!) {
      throw const ApiException(
          code: 'limit_reached', message: 'full', statusCode: 429);
    }
    createCalls++;
    return createdResult ?? _item('created-$createCalls');
  }

  @override
  Future<WardrobeItem> addImages(
      String itemId, List<PickedImage> images) async {
    addImagesCalls++;
    return addImagesResult ?? _item(itemId);
  }

  @override
  Future<void> deleteItem(String itemId) async {
    deletedId = itemId;
  }
}

WardrobeItem _item(
  String id, {
  String name = 'Item',
  String category = 'tops',
  bool isFavorite = false,
}) =>
    WardrobeItem(
      id: id,
      name: name,
      category: category,
      wornCount: 0,
      isFavorite: isFavorite,
      isStarterWardrobe: false,
      addedVia: 'manual',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

void main() {
  late _FakeWardrobeService service;
  late WardrobeController controller;

  setUp(() {
    service = _FakeWardrobeService();
    controller = WardrobeController(service);
  });

  test('load populates items and total', () async {
    service
      ..totalToReport = 2
      ..pageBuilder = (_) => [_item('a'), _item('b')];

    await controller.load();

    expect(controller.state.items.map((i) => i.id), ['a', 'b']);
    expect(controller.state.total, 2);
    expect(controller.state.loading, isFalse);
    expect(service.lastCategory, isNull); // "all" → no category param
  });

  test('selectCategory sends the category query and reloads', () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('x', category: 'shoes')];

    await controller.selectCategory(WardrobeCategoryFilter.shoes);

    expect(service.lastCategory, 'shoes');
    expect(controller.state.category, WardrobeCategoryFilter.shoes);
    expect(controller.state.items.single.id, 'x');
  });

  test('setSearch filters visibleItems client-side without a refetch', () async {
    service
      ..totalToReport = 2
      ..pageBuilder = (_) => [
            _item('a', name: 'Linen Shirt'),
            _item('b', name: 'Denim Jacket'),
          ];
    await controller.load();
    final offsetAfterLoad = service.lastOffset;

    controller.setSearch('denim');

    expect(controller.state.visibleItems.map((i) => i.id), ['b']);
    expect(controller.state.items, hasLength(2)); // underlying list untouched
    expect(service.lastOffset, offsetAfterLoad); // no new fetch
  });

  test('loadMore appends the next page and stops when caught up', () async {
    service
      ..totalToReport = 3
      ..pageBuilder = (offset) =>
          offset == 0 ? [_item('a'), _item('b')] : [_item('c')];

    await controller.load();
    expect(controller.state.hasMore, isTrue);

    await controller.loadMore();
    expect(service.lastOffset, 2); // requested offset == loaded count
    expect(controller.state.items.map((i) => i.id), ['a', 'b', 'c']);
    expect(controller.state.hasMore, isFalse);

    // No further pages — loadMore is a no-op.
    service.lastOffset = -1;
    await controller.loadMore();
    expect(service.lastOffset, -1);
  });

  test('toggleFavorite optimistically flips, then confirms from the server',
      () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('a')]; // starts not-favorite
    await controller.load();
    service.favoriteResult = const ToggleFavoriteResult(
      itemId: 'a',
      isFavorite: true,
    );

    await controller.toggleFavorite('a');

    expect(controller.state.items.single.isFavorite, isTrue);
  });

  test('toggleFavorite reverts and rethrows on error', () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('a')];
    await controller.load();
    service.favoriteError = const ApiException(
      code: 'server_error',
      message: 'boom',
      statusCode: 500,
    );

    await expectLater(
      controller.toggleFavorite('a'),
      throwsA(isA<ApiException>()),
    );
    // Optimistic flip was rolled back.
    expect(controller.state.items.single.isFavorite, isFalse);
  });

  test('selectFavorites queries is_favorite and resets the category', () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('a', isFavorite: true)];
    await controller.selectCategory(WardrobeCategoryFilter.shoes);

    await controller.selectFavorites();

    expect(service.lastIsFavorite, isTrue);
    expect(service.lastCategory, isNull); // category reset to "all"
    expect(controller.state.favoritesOnly, isTrue);
    expect(controller.state.category, WardrobeCategoryFilter.all);
  });

  test('selectCategory leaves the favorites view, even onto the same category',
      () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('a', isFavorite: true)];
    await controller.selectFavorites();

    // Favorites resets the category to "all", so re-selecting "all" must not
    // be treated as a no-op.
    await controller.selectCategory(WardrobeCategoryFilter.all);

    expect(controller.state.favoritesOnly, isFalse);
    expect(service.lastIsFavorite, isNull);
  });

  test('toggleFavorite in the favorites view drops the unfavorited item',
      () async {
    service
      ..totalToReport = 2
      ..pageBuilder = (_) => [
            _item('a', isFavorite: true),
            _item('b', isFavorite: true),
          ];
    await controller.selectFavorites();
    service.favoriteResult = const ToggleFavoriteResult(
      itemId: 'a',
      isFavorite: false,
    );

    await controller.toggleFavorite('a');

    expect(controller.state.items.map((i) => i.id), ['b']);
    expect(controller.state.total, 1);
  });

  test('logWorn patches the worn counters in the grid', () async {
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('a')];
    await controller.load();
    service.logResult = LogWornResult.fromJson({
      'item_id': 'a',
      'worn_count': 1,
      'last_worn': '2026-05-23',
      'cost_per_wear': 9.99,
      'already_logged_today': false,
    });

    final result = await controller.logWorn('a');

    expect(result.alreadyLoggedToday, isFalse);
    final item = controller.state.items.single;
    expect(item.wornCount, 1);
    expect(item.costPerWear, 9.99);
  });

  test('deleteItem removes the item and decrements total', () async {
    service
      ..totalToReport = 2
      ..pageBuilder = (_) => [_item('a'), _item('b')];
    await controller.load();

    await controller.deleteItem('a');

    expect(service.deletedId, 'a');
    expect(controller.state.items.map((i) => i.id), ['b']);
    expect(controller.state.total, 1);
  });

  test('createItem reloads the grid with the new item', () async {
    service
      ..totalToReport = 0
      ..pageBuilder = (_) => const [];
    await controller.load();
    expect(controller.state.items, isEmpty);

    // After create, the next load returns the created row.
    service.createdResult = _item('new');
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('new')];

    final created = await controller.createItem(const WardrobeItemInput(
      name: 'New',
      category: 'tops',
    ));

    expect(created.id, 'new');
    expect(controller.state.items.single.id, 'new');
  });

  test('createItemWithImages creates, attaches the photo, then reloads',
      () async {
    service
      ..totalToReport = 0
      ..pageBuilder = (_) => const [];
    await controller.load();

    service.createdResult = _item('scanned');
    service.addImagesResult = _item('scanned');
    service
      ..totalToReport = 1
      ..pageBuilder = (_) => [_item('scanned')];

    final created = await controller.createItemWithImages(
      const WardrobeItemInput(name: 'White Tops', category: 'tops'),
      [PickedImage(bytes: Uint8List(0), filename: 'x.jpg', mimeType: 'image/jpeg')],
    );

    expect(created.id, 'scanned');
    expect(service.addImagesCalls, 1); // photo attached
    expect(controller.state.items.single.id, 'scanned'); // grid reloaded
  });

  ({WardrobeItemInput input, PickedImage? image}) entry(String name,
          {bool withImage = false}) =>
      (
        input: WardrobeItemInput(name: name, category: 'tops'),
        image: withImage
            ? PickedImage(
                bytes: Uint8List(0), filename: 'x.jpg', mimeType: 'image/jpeg')
            : null,
      );

  test('createBatch creates every entry and attaches photos where present',
      () async {
    service
      ..totalToReport = 2
      ..pageBuilder = (_) => [_item('a'), _item('b')];

    final outcome = await controller.createBatch([
      entry('One', withImage: true),
      entry('Two'),
      entry('Three', withImage: true),
    ]);

    expect(outcome.created, 3);
    expect(outcome.limitReached, isFalse);
    expect(outcome.error, isNull);
    expect(service.addImagesCalls, 2); // only the two with images
  });

  test('createBatch stops at the 429 cap and reports how many got in',
      () async {
    service
      ..totalToReport = 0
      ..create429AfterNthSuccess = 2 // 3rd create 429s
      ..pageBuilder = (_) => const [];

    final outcome = await controller.createBatch([
      entry('One'),
      entry('Two'),
      entry('Three'),
      entry('Four'),
    ]);

    expect(outcome.created, 2);
    expect(outcome.limitReached, isTrue);
  });
}
