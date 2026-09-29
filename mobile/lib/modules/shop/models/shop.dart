/// Wire models for `/shop/*` (items 7a–7e). Mirrors backend `schemas/shop.py`.
library;

class ShopProduct {
  const ShopProduct({
    required this.id,
    required this.name,
    required this.brand,
    required this.category,
    required this.priceCents,
    required this.currency,
    required this.imageUrl,
    required this.productUrl,
    required this.retailer,
  });

  final String id;
  final String name;
  final String brand;
  final String category;
  final int priceCents;
  final String currency;
  final String imageUrl;
  final String productUrl;
  final String retailer;

  String get priceLabel => '\$${(priceCents / 100).toStringAsFixed(2)}';

  factory ShopProduct.fromJson(Map<String, dynamic> json) => ShopProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String,
        category: json['category'] as String,
        priceCents: json['price_cents'] as int,
        currency: json['currency'] as String? ?? 'CAD',
        imageUrl: json['image_url'] as String? ?? '',
        productUrl: json['product_url'] as String? ?? '',
        retailer: json['retailer'] as String? ?? '',
      );
}

class ShopFeed {
  const ShopFeed({required this.products, required this.measurementsComplete});

  final List<ShopProduct> products;
  final bool measurementsComplete;

  factory ShopFeed.fromJson(Map<String, dynamic> json) => ShopFeed(
        products: (json['products'] as List<dynamic>)
            .map((e) => ShopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        measurementsComplete: json['measurements_complete'] as bool? ?? false,
      );
}

/// A real catalog product inside an advisor look — snapshotted server-side,
/// so it carries everything the card and the Buy link need.
class AdvisorLookItem {
  const AdvisorLookItem({
    required this.productId,
    required this.name,
    required this.brand,
    required this.category,
    required this.priceCents,
    required this.currency,
    required this.imageUrl,
    required this.productUrl,
    required this.retailer,
  });

  final String productId;
  final String name;
  final String brand;
  final String category;
  final int priceCents;
  final String currency;
  final String imageUrl;
  final String productUrl;
  final String retailer;

  String get priceLabel => '\$${(priceCents / 100).toStringAsFixed(0)}';

  factory AdvisorLookItem.fromJson(Map<String, dynamic> json) =>
      AdvisorLookItem(
        productId: json['product_id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String? ?? '',
        category: json['category'] as String? ?? '',
        priceCents: json['price_cents'] as int,
        currency: json['currency'] as String? ?? 'CAD',
        imageUrl: json['image_url'] as String? ?? '',
        productUrl: json['product_url'] as String? ?? '',
        retailer: json['retailer'] as String? ?? '',
      );
}

/// One of up to 3 looks in a stylist reply.
class AdvisorLook {
  const AdvisorLook({
    required this.name,
    required this.note,
    required this.items,
    required this.totalPriceCents,
  });

  final String name;
  final String note; // ties the look to the user's wardrobe; may be empty
  final List<AdvisorLookItem> items;
  final int totalPriceCents;

  String get totalLabel => '~\$${(totalPriceCents / 100).toStringAsFixed(0)}';

  factory AdvisorLook.fromJson(Map<String, dynamic> json) => AdvisorLook(
        name: json['name'] as String? ?? '',
        note: json['note'] as String? ?? '',
        items: (json['items'] as List<dynamic>? ?? const [])
            .map((e) => AdvisorLookItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalPriceCents: json['total_price_cents'] as int? ?? 0,
      );
}

class AdvisorMessage {
  const AdvisorMessage({
    required this.role,
    required this.content,
    this.looks = const [],
  });

  final String role; // user | assistant
  final String content;
  // Empty for plain answers and for conversations saved before looks existed.
  final List<AdvisorLook> looks;

  factory AdvisorMessage.fromJson(Map<String, dynamic> json) => AdvisorMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        looks: (json['looks'] as List<dynamic>? ?? const [])
            .map((e) => AdvisorLook.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AdvisorConversation {
  const AdvisorConversation({
    required this.id,
    required this.title,
    required this.messages,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final List<AdvisorMessage> messages;
  final DateTime updatedAt;

  factory AdvisorConversation.fromJson(Map<String, dynamic> json) =>
      AdvisorConversation(
        id: json['id'] as String,
        title: json['title'] as String,
        messages: (json['messages'] as List<dynamic>)
            .map((e) => AdvisorMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );
}

class BuyDontBuyVerdict {
  const BuyDontBuyVerdict({
    required this.id,
    required this.verdict,
    required this.score,
    required this.fitReason,
    required this.valueReason,
    required this.gapReason,
    required this.createdAt,
    this.productName,
  });

  final String id;
  final String verdict; // buy | dont_buy
  final int score;
  final String fitReason;
  final String valueReason;
  final String gapReason;
  final DateTime createdAt;
  final String? productName;

  bool get isBuy => verdict == 'buy';

  factory BuyDontBuyVerdict.fromJson(Map<String, dynamic> json) =>
      BuyDontBuyVerdict(
        id: json['id'] as String,
        verdict: json['verdict'] as String,
        score: json['score'] as int,
        fitReason: json['fit_reason'] as String? ?? '',
        valueReason: json['value_reason'] as String? ?? '',
        gapReason: json['gap_reason'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        productName: json['product_name'] as String?,
      );
}

class GapItem {
  const GapItem({
    required this.category,
    required this.have,
    required this.recommended,
    required this.reason,
    required this.outfitsUnlocked,
  });

  final String category;
  final int have;
  final int recommended;
  final String reason;
  final int outfitsUnlocked;

  factory GapItem.fromJson(Map<String, dynamic> json) => GapItem(
        category: json['category'] as String,
        have: json['have'] as int,
        recommended: json['recommended'] as int,
        reason: json['reason'] as String? ?? '',
        outfitsUnlocked: json['outfits_unlocked'] as int? ?? 0,
      );
}

class GapAnalysis {
  const GapAnalysis({
    required this.gaps,
    required this.isTeaser,
    this.proTeaser,
  });

  final List<GapItem> gaps;
  final bool isTeaser;
  final String? proTeaser;

  factory GapAnalysis.fromJson(Map<String, dynamic> json) => GapAnalysis(
        gaps: (json['gaps'] as List<dynamic>)
            .map((e) => GapItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        isTeaser: json['is_teaser'] as bool? ?? false,
        proTeaser: json['pro_teaser'] as String?,
      );
}

class WishlistEntry {
  const WishlistEntry({
    required this.product,
    required this.addedPriceCents,
    required this.priceDropCents,
    this.currentPriceCents,
  });

  final ShopProduct product;
  final int addedPriceCents;
  final int priceDropCents; // 0 = no drop
  final int? currentPriceCents;

  bool get hasDrop => priceDropCents > 0;

  factory WishlistEntry.fromJson(Map<String, dynamic> json) => WishlistEntry(
        product: ShopProduct.fromJson(json['product'] as Map<String, dynamic>),
        addedPriceCents: json['added_price_cents'] as int,
        priceDropCents: json['price_drop_cents'] as int? ?? 0,
        currentPriceCents: json['current_price_cents'] as int?,
      );
}
