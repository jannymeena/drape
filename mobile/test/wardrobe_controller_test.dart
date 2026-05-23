import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/wardrobe_controller.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';

/// A wardrobe service with canned, call-recording responses so the controller's
/// filter / search / paging logic can be tested without Dio.
class _FakeWardrobeService extends WardrobeService {
  _FakeWardrobeService() : super(Dio());

  String? lastCategory;
  int lastOffset = -1;
  int totalToReport = 0;
  List<WardrobeItem> Function(int offset)? pageBuilder;

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async {
    lastCategory = category;
    lastOffset = offset;
    final items = pageBuilder?.call(offset) ?? const <WardrobeItem>[];
    return WardrobeListResult(
      items: items,
      total: totalToReport,
      limit: limit,
      offset: offset,
    );
  }
}

WardrobeItem _item(String id, {String name = 'Item', String category = 'tops'}) =>
    WardrobeItem(
      id: id,
      name: name,
      category: category,
      wornCount: 0,
      isFavorite: false,
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
}
