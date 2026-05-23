import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import 'image_pick.dart';
import 'models/wardrobe_item.dart';
import 'models/wardrobe_mutations.dart';
import 'wardrobe_service.dart';

/// State for the wardrobe grid. [items] is the loaded page(s) for the current
/// [category]; [total] is the server's count for that filter, so [hasMore] can
/// drive a "load more". [search] is a client-side name filter (the backend list
/// endpoint has no text search) applied on top via [visibleItems].
///
/// Free-tier capacity lives in its own [wardrobeCapacityProvider] (it composes
/// the item count with the subscription tier), keeping this controller focused
/// on the grid + mutations.
class WardrobeState {
  const WardrobeState({
    this.loading = false,
    this.loadingMore = false,
    this.items = const [],
    this.total = 0,
    this.error,
    this.category = WardrobeCategoryFilter.all,
    this.search = '',
  });

  final bool loading;
  final bool loadingMore;
  final List<WardrobeItem> items;
  final int total;
  final ApiException? error;
  final WardrobeCategoryFilter category;
  final String search;

  bool get hasData => items.isNotEmpty;
  bool get hasMore => items.length < total;

  /// [items] with the client-side name search applied.
  List<WardrobeItem> get visibleItems {
    final q = search.trim().toLowerCase();
    if (q.isEmpty) return items;
    return items.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  WardrobeState copyWith({
    bool? loading,
    bool? loadingMore,
    List<WardrobeItem>? items,
    int? total,
    ApiException? error,
    WardrobeCategoryFilter? category,
    String? search,
  }) {
    return WardrobeState(
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      items: items ?? this.items,
      total: total ?? this.total,
      error: error,
      category: category ?? this.category,
      search: search ?? this.search,
    );
  }
}

class WardrobeController extends StateNotifier<WardrobeState> {
  WardrobeController(this._service) : super(const WardrobeState());

  final WardrobeService _service;

  static const _pageSize = 50;

  /// Loads the first page for the current category. Keeps the existing items
  /// visible while refreshing so the grid doesn't flash empty.
  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final result = await _service.getItems(
        category: state.category.query,
        limit: _pageSize,
        offset: 0,
      );
      state = state.copyWith(
        loading: false,
        items: result.items,
        total: result.total,
      );
    } on ApiException catch (e) {
      state = state.copyWith(loading: false, error: e);
    }
  }

  /// Switches the active category chip and reloads from the server (category is
  /// a server-side filter). No-op if already selected.
  Future<void> selectCategory(WardrobeCategoryFilter category) async {
    if (category == state.category) return;
    state = state.copyWith(category: category, items: const [], total: 0);
    await load();
  }

  /// Sets the client-side name filter. No network call.
  void setSearch(String query) {
    state = state.copyWith(search: query);
  }

  /// Appends the next page when [WardrobeState.hasMore]. Best-effort: a failure
  /// just clears the spinner (the partial list stays usable).
  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    try {
      final result = await _service.getItems(
        category: state.category.query,
        limit: _pageSize,
        offset: state.items.length,
      );
      state = state.copyWith(
        loadingMore: false,
        items: [...state.items, ...result.items],
        total: result.total,
      );
    } on ApiException {
      state = state.copyWith(loadingMore: false);
    }
  }

  /// Optimistically flips the favorite flag, then persists. When the item is in
  /// the loaded grid it's patched optimistically (and reverted on error); when
  /// it isn't (e.g. opened via deep link), the toggle still persists. Rethrows
  /// for UI feedback.
  Future<void> toggleFavorite(String itemId) async {
    final index = state.items.indexWhere((i) => i.id == itemId);
    final original = index >= 0 ? state.items[index] : null;

    if (original != null) {
      _replaceItem(
        itemId,
        original.copyWith(
          isFavorite: !original.isFavorite,
          favoritedAt: original.isFavorite ? null : DateTime.now(),
        ),
      );
    }
    try {
      final result = await _service.toggleFavorite(itemId);
      if (original != null) {
        _replaceItem(
          itemId,
          original.copyWith(
            isFavorite: result.isFavorite,
            favoritedAt: result.favoritedAt,
          ),
        );
      }
    } on ApiException {
      if (original != null) _replaceItem(itemId, original); // revert
      rethrow;
    }
  }

  /// Logs a wear and patches the item's counters in the grid. Returns the
  /// result (incl. `alreadyLoggedToday`) for the caller's toast. Rethrows on
  /// error.
  Future<LogWornResult> logWorn(String itemId) async {
    final result = await _service.logWorn(itemId);
    final index = state.items.indexWhere((i) => i.id == itemId);
    if (index >= 0) {
      _replaceItem(
        itemId,
        state.items[index].copyWith(
          wornCount: result.wornCount,
          lastWorn: result.lastWorn,
          costPerWear: result.costPerWear,
        ),
      );
    }
    return result;
  }

  /// Creates an item, then reloads the grid (so filters/order stay correct).
  /// Rethrows (incl. 429 `limit_reached`) for UI feedback.
  Future<WardrobeItem> createItem(WardrobeItemInput input) async {
    final created = await _service.createItem(input);
    await load();
    return created;
  }

  /// Creates an item from a scan, then attaches the captured photo(s) before
  /// reloading the grid once (so the new card shows its image). Rethrows on
  /// failure (incl. 429); image attach failures propagate too — the item is
  /// already created, so callers should surface a "saved without photo" hint.
  Future<WardrobeItem> createItemWithImages(
    WardrobeItemInput input,
    List<PickedImage> images,
  ) async {
    var created = await _service.createItem(input);
    if (images.isNotEmpty) {
      created = await _service.addImages(created.id, images);
    }
    await load();
    return created;
  }

  /// Creates a batch of items (each with an optional photo). Best-effort and
  /// resilient: it keeps going past an individual item's failure, but stops on
  /// a 429 (cap reached). Reloads once at the end. Returns how many were
  /// created, whether the cap was hit, and the first non-cap error (if any).
  Future<({int created, bool limitReached, ApiException? error})> createBatch(
    List<({WardrobeItemInput input, PickedImage? image})> entries,
  ) async {
    var created = 0;
    var limitReached = false;
    ApiException? error;
    for (final entry in entries) {
      try {
        final item = await _service.createItem(entry.input);
        if (entry.image != null) {
          await _service.addImages(item.id, [entry.image!]);
        }
        created++;
      } on ApiException catch (e) {
        if (e.statusCode == 429) {
          limitReached = true;
          break; // cap hit — no point trying the rest
        }
        error ??= e; // record the first error, skip this one, keep going
      }
    }
    if (created > 0) await load();
    return (created: created, limitReached: limitReached, error: error);
  }

  /// Attaches photos to an existing item and swaps the returned item into the
  /// grid.
  Future<WardrobeItem> addImages(String itemId, List<PickedImage> images) async {
    final updated = await _service.addImages(itemId, images);
    _replaceItem(itemId, updated);
    return updated;
  }

  /// Applies a partial update and swaps the returned item into the grid.
  Future<WardrobeItem> updateItem(String itemId, WardrobeItemInput input) async {
    final updated = await _service.updateItem(itemId, input);
    _replaceItem(itemId, updated);
    return updated;
  }

  /// Deletes an item and removes it from the grid.
  Future<void> deleteItem(String itemId) async {
    await _service.deleteItem(itemId);
    final remaining = state.items.where((i) => i.id != itemId).toList();
    state = state.copyWith(
      items: remaining,
      total: (state.total - 1).clamp(0, 1 << 30),
    );
  }

  void _replaceItem(String itemId, WardrobeItem item) {
    state = state.copyWith(
      items: [
        for (final i in state.items) i.id == itemId ? item : i,
      ],
    );
  }
}

final wardrobeControllerProvider =
    StateNotifierProvider<WardrobeController, WardrobeState>((ref) {
  return WardrobeController(ref.read(wardrobeServiceProvider));
});
