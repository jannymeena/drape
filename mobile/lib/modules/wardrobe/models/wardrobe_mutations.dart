/// Write payloads + action results for the wardrobe mutation endpoints
/// (`app/schemas/wardrobe.py`): create (`WardrobeItemCreate`), partial update
/// (`WardrobeItemUpdate`), `LogWornResponse`, `ToggleFavoriteResponse`.
library;

/// Builds the body for `POST /wardrobe/items` (create) and
/// `PATCH /wardrobe/items/{id}` (partial update). [toJson] omits null fields, so
/// the same object serves both: create callers set name + category; patch
/// callers set only what changed.
class WardrobeItemInput {
  const WardrobeItemInput({
    this.name,
    this.category,
    this.subcategory,
    this.colorName,
    this.colorHex,
    this.pattern,
    this.material,
    this.formality,
    this.season,
    this.brand,
    this.purchasePrice,
    this.purchaseDate,
    this.description,
    this.primaryImageUrl,
    this.images,
  });

  final String? name;
  final String? category;
  final String? subcategory;
  final String? colorName;
  final String? colorHex;
  final String? pattern;
  final String? material;
  final String? formality;
  final List<String>? season;
  final String? brand;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? description;
  final String? primaryImageUrl;
  final List<String>? images;

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    void put(String key, Object? value) {
      if (value != null) json[key] = value;
    }

    put('name', name);
    put('category', category);
    put('subcategory', subcategory);
    put('color_name', colorName);
    put('color_hex', colorHex);
    put('pattern', pattern);
    put('material', material);
    put('formality', formality);
    put('season', season);
    put('brand', brand);
    put('purchase_price', purchasePrice);
    put('purchase_date', purchaseDate == null ? null : _isoDate(purchaseDate!));
    put('description', description);
    put('primary_image_url', primaryImageUrl);
    put('images', images);
    return json;
  }

  static String _isoDate(DateTime d) {
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }
}

class LogWornResult {
  const LogWornResult({
    required this.itemId,
    required this.wornCount,
    required this.lastWorn,
    required this.alreadyLoggedToday,
    this.costPerWear,
  });

  final String itemId;
  final int wornCount;
  final DateTime lastWorn;
  final double? costPerWear;
  final bool alreadyLoggedToday;

  factory LogWornResult.fromJson(Map<String, dynamic> json) {
    return LogWornResult(
      itemId: json['item_id'] as String,
      wornCount: json['worn_count'] as int? ?? 0,
      lastWorn: DateTime.parse(json['last_worn'] as String),
      costPerWear: (json['cost_per_wear'] as num?)?.toDouble(),
      alreadyLoggedToday: json['already_logged_today'] as bool? ?? false,
    );
  }
}

class ToggleFavoriteResult {
  const ToggleFavoriteResult({
    required this.itemId,
    required this.isFavorite,
    this.favoritedAt,
  });

  final String itemId;
  final bool isFavorite;
  final DateTime? favoritedAt;

  factory ToggleFavoriteResult.fromJson(Map<String, dynamic> json) {
    return ToggleFavoriteResult(
      itemId: json['item_id'] as String,
      isFavorite: json['is_favorite'] as bool? ?? false,
      favoritedAt: json['favorited_at'] == null
          ? null
          : DateTime.parse(json['favorited_at'] as String),
    );
  }
}

/// Free-tier wardrobe capacity. [used] is the count of non-starter items; [cap]
/// mirrors the backend `FREE_TIER_REAL_ITEM_LIMIT` (30). The banner is hidden
/// for Pro (unlimited) and below the soft threshold.
class WardrobeCapacity {
  const WardrobeCapacity({
    required this.used,
    required this.isPro,
    this.cap = 30,
  });

  final int used;
  final int cap;
  final bool isPro;

  static const _soft = 22;
  static const _urgent = 27;

  int get remaining => (cap - used).clamp(0, cap);

  bool get shouldShowBanner => !isPro && used >= _soft;

  /// "soft" | "urgent" | "blocked" — matches `CapacityLevel` in the banner.
  String get level {
    if (used >= cap) return 'blocked';
    if (used >= _urgent) return 'urgent';
    return 'soft';
  }

  /// Trailing detail for the item-added toast ("27/30 items") once [added]
  /// more items land, computed from this pre-add snapshot so the toast never
  /// waits on a refetch. Null for Pro — no cap to show.
  String? toastDetailAfterAdding(int added) {
    if (isPro) return null;
    return '${(used + added).clamp(0, cap)}/$cap items';
  }
}
