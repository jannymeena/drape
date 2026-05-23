/// Mirrors the backend `WardrobeItemResponse` / `WardrobeListResponse`
/// (`app/schemas/wardrobe.py`). Categorical fields are backend Literals carried
/// as plain strings; nullable everywhere the schema is.
library;

class WardrobeItem {
  const WardrobeItem({
    required this.id,
    required this.name,
    required this.category,
    required this.wornCount,
    required this.isFavorite,
    required this.isStarterWardrobe,
    required this.addedVia,
    required this.createdAt,
    required this.updatedAt,
    this.subcategory,
    this.images,
    this.primaryImageUrl,
    this.colorHex,
    this.colorName,
    this.pattern,
    this.material,
    this.formality,
    this.season,
    this.brand,
    this.purchasePrice,
    this.purchaseDate,
    this.description,
    this.lastWorn,
    this.costPerWear,
    this.favoritedAt,
    this.starterTemplateId,
    this.aiDetectionConfidence,
  });

  final String id;
  final String name;
  final String category; // tops | bottoms | dresses | shoes | outerwear | accessories | bags | jewelry
  final String? subcategory;
  final List<String>? images;
  final String? primaryImageUrl;
  final String? colorHex;
  final String? colorName;
  final String? pattern;
  final String? material;
  final String? formality;
  final List<String>? season;
  final String? brand;
  final double? purchasePrice;
  final DateTime? purchaseDate;
  final String? description;
  final int wornCount;
  final DateTime? lastWorn;
  final double? costPerWear;
  final bool isFavorite;
  final DateTime? favoritedAt;
  final bool isStarterWardrobe;
  final String? starterTemplateId;
  final String addedVia; // manual | scan | batch_upload | starter_seed
  final int? aiDetectionConfidence;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// First usable image for the card/hero (primary, else the first uploaded).
  String? get displayImageUrl {
    if (primaryImageUrl != null && primaryImageUrl!.isNotEmpty) {
      return primaryImageUrl;
    }
    final imgs = images;
    if (imgs != null && imgs.isNotEmpty) return imgs.first;
    return null;
  }

  /// `outerwear` → "Outerwear".
  String get categoryLabel => _titleCase(category);

  /// "March 2024" from [createdAt] (local).
  String get addedLabel {
    final d = createdAt.toLocal();
    return '${_months[d.month - 1]} ${d.year}';
  }

  /// Relative "Last worn" label, or null if never worn.
  String? get lastWornLabel {
    final worn = lastWorn?.toLocal();
    if (worn == null) return null;
    final today = DateTime.now();
    final days =
        DateTime(today.year, today.month, today.day).difference(
              DateTime(worn.year, worn.month, worn.day),
            ).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    if (days < 7) return '$days days ago';
    if (days < 30) return '${(days / 7).floor()} weeks ago';
    return '${_months[worn.month - 1]} ${worn.day}';
  }

  static DateTime? _parseDate(Object? v) =>
      v == null ? null : DateTime.parse(v as String);

  factory WardrobeItem.fromJson(Map<String, dynamic> json) {
    return WardrobeItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      subcategory: json['subcategory'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
      primaryImageUrl: json['primary_image_url'] as String?,
      colorHex: json['color_hex'] as String?,
      colorName: json['color_name'] as String?,
      pattern: json['pattern'] as String?,
      material: json['material'] as String?,
      formality: json['formality'] as String?,
      season: (json['season'] as List<dynamic>?)?.map((e) => e as String).toList(),
      brand: json['brand'] as String?,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      purchaseDate: _parseDate(json['purchase_date']),
      description: json['description'] as String?,
      wornCount: json['worn_count'] as int? ?? 0,
      lastWorn: _parseDate(json['last_worn']),
      costPerWear: (json['cost_per_wear'] as num?)?.toDouble(),
      isFavorite: json['is_favorite'] as bool? ?? false,
      favoritedAt: _parseDate(json['favorited_at']),
      isStarterWardrobe: json['is_starter_wardrobe'] as bool? ?? false,
      starterTemplateId: json['starter_template_id'] as String?,
      addedVia: json['added_via'] as String? ?? 'manual',
      aiDetectionConfidence: json['ai_detection_confidence'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}

class WardrobeListResult {
  const WardrobeListResult({
    required this.items,
    required this.total,
    required this.limit,
    required this.offset,
  });

  final List<WardrobeItem> items;
  final int total;
  final int limit;
  final int offset;

  factory WardrobeListResult.fromJson(Map<String, dynamic> json) {
    return WardrobeListResult(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => WardrobeItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      limit: json['limit'] as int? ?? 0,
      offset: json['offset'] as int? ?? 0,
    );
  }
}

/// The category filter chips. `all` sends no `category` param; the rest map to
/// the backend `Category` literal in [query].
enum WardrobeCategoryFilter {
  all(null, 'All Pieces'),
  tops('tops', 'Tops'),
  bottoms('bottoms', 'Bottoms'),
  dresses('dresses', 'Dresses'),
  outerwear('outerwear', 'Outerwear'),
  shoes('shoes', 'Shoes'),
  accessories('accessories', 'Accessories'),
  bags('bags', 'Bags'),
  jewelry('jewelry', 'Jewelry');

  const WardrobeCategoryFilter(this.query, this.label);

  final String? query;
  final String label;
}

String _titleCase(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];
