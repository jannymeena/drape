import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/models/api_error.dart';
import 'models/wardrobe_item.dart';
import 'wardrobe_service.dart';

/// State for the wardrobe grid. [items] is the loaded page(s) for the current
/// [category]; [total] is the server's count for that filter, so [hasMore] can
/// drive a "load more". [search] is a client-side name filter (the backend list
/// endpoint has no text search) applied on top via [visibleItems].
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
}

final wardrobeControllerProvider =
    StateNotifierProvider<WardrobeController, WardrobeState>((ref) {
  return WardrobeController(ref.read(wardrobeServiceProvider));
});
