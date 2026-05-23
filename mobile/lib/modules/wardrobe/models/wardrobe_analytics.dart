/// Mirrors the backend wardrobe analytics shapes (`app/schemas/analytics.py`):
/// cost-per-wear, utilization-score, weekly-report (all free) and the Pro-only
/// intelligence-report.
library;

// ── cost-per-wear ──────────────────────────────────────────────────────────

class CostPerWearItem {
  const CostPerWearItem({
    required this.itemId,
    required this.name,
    required this.category,
    required this.wornCount,
    this.purchasePrice,
    this.costPerWear,
  });

  final String itemId;
  final String name;
  final String category;
  final int wornCount;
  final double? purchasePrice;
  final double? costPerWear;

  factory CostPerWearItem.fromJson(Map<String, dynamic> json) {
    return CostPerWearItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      wornCount: json['worn_count'] as int? ?? 0,
      purchasePrice: (json['purchase_price'] as num?)?.toDouble(),
      costPerWear: (json['cost_per_wear'] as num?)?.toDouble(),
    );
  }
}

class CostPerWearCategory {
  const CostPerWearCategory({
    required this.category,
    required this.itemCount,
    required this.totalPurchasePrice,
    required this.totalWears,
    this.averageCostPerWear,
  });

  final String category;
  final int itemCount;
  final double totalPurchasePrice;
  final int totalWears;
  final double? averageCostPerWear;

  factory CostPerWearCategory.fromJson(Map<String, dynamic> json) {
    return CostPerWearCategory(
      category: json['category'] as String,
      itemCount: json['item_count'] as int? ?? 0,
      totalPurchasePrice:
          (json['total_purchase_price'] as num?)?.toDouble() ?? 0,
      totalWears: json['total_wears'] as int? ?? 0,
      averageCostPerWear: (json['average_cost_per_wear'] as num?)?.toDouble(),
    );
  }
}

class CostPerWearReport {
  const CostPerWearReport({
    required this.items,
    required this.categories,
    required this.totalItemsWithPrice,
    required this.totalItemsWithWears,
  });

  final List<CostPerWearItem> items;
  final List<CostPerWearCategory> categories;
  final int totalItemsWithPrice;
  final int totalItemsWithWears;

  factory CostPerWearReport.fromJson(Map<String, dynamic> json) {
    return CostPerWearReport(
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => CostPerWearItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      categories: (json['categories'] as List<dynamic>? ?? const [])
          .map((e) => CostPerWearCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalItemsWithPrice: json['total_items_with_price'] as int? ?? 0,
      totalItemsWithWears: json['total_items_with_wears'] as int? ?? 0,
    );
  }
}

// ── utilization-score ──────────────────────────────────────────────────────

class UtilizationScore {
  const UtilizationScore({
    required this.score,
    required this.itemsWornRecently,
    required this.itemsTotal,
    required this.daysWindow,
    required this.label,
  });

  final int score;
  final int itemsWornRecently;
  final int itemsTotal;
  final int daysWindow;
  final String label; // Low / Moderate / High

  factory UtilizationScore.fromJson(Map<String, dynamic> json) {
    return UtilizationScore(
      score: json['score'] as int? ?? 0,
      itemsWornRecently: json['items_worn_recently'] as int? ?? 0,
      itemsTotal: json['items_total'] as int? ?? 0,
      daysWindow: json['days_window'] as int? ?? 30,
      label: json['label'] as String? ?? '',
    );
  }
}

// ── weekly-report (free teaser) ──────────────────────────────────────────────

class WeeklyReportTopItem {
  const WeeklyReportTopItem({
    required this.itemId,
    required this.name,
    required this.wornCount,
  });

  final String itemId;
  final String name;
  final int wornCount;

  factory WeeklyReportTopItem.fromJson(Map<String, dynamic> json) {
    return WeeklyReportTopItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      wornCount: json['worn_count'] as int? ?? 0,
    );
  }
}

class WeeklyReport {
  const WeeklyReport({
    required this.weekStartDate,
    required this.outfitsLogged,
    required this.itemsWornDistinct,
    required this.topItems,
    required this.streakDays,
    required this.proTeaser,
  });

  final DateTime weekStartDate;
  final int outfitsLogged;
  final int itemsWornDistinct;
  final List<WeeklyReportTopItem> topItems;
  final int streakDays;
  final String proTeaser;

  factory WeeklyReport.fromJson(Map<String, dynamic> json) {
    return WeeklyReport(
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
      outfitsLogged: json['outfits_logged'] as int? ?? 0,
      itemsWornDistinct: json['items_worn_distinct'] as int? ?? 0,
      topItems: (json['top_items'] as List<dynamic>? ?? const [])
          .map((e) => WeeklyReportTopItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      streakDays: json['streak_days'] as int? ?? 0,
      proTeaser: json['pro_teaser'] as String? ?? '',
    );
  }
}

// ── intelligence-report (Pro) ────────────────────────────────────────────────

class IntelligenceColorBucket {
  const IntelligenceColorBucket({
    required this.colorName,
    required this.itemCount,
    required this.wornCount,
  });

  final String colorName;
  final int itemCount;
  final int wornCount;

  factory IntelligenceColorBucket.fromJson(Map<String, dynamic> json) {
    return IntelligenceColorBucket(
      colorName: json['color_name'] as String? ?? 'Other',
      itemCount: json['item_count'] as int? ?? 0,
      wornCount: json['worn_count'] as int? ?? 0,
    );
  }
}

class IntelligenceUnderutilized {
  const IntelligenceUnderutilized({
    required this.itemId,
    required this.name,
    required this.category,
    required this.wornCount,
    this.daysSinceLastWorn,
  });

  final String itemId;
  final String name;
  final String category;
  final int wornCount;
  final int? daysSinceLastWorn;

  factory IntelligenceUnderutilized.fromJson(Map<String, dynamic> json) {
    return IntelligenceUnderutilized(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      wornCount: json['worn_count'] as int? ?? 0,
      daysSinceLastWorn: json['days_since_last_worn'] as int?,
    );
  }
}

class IntelligenceReport {
  const IntelligenceReport({
    required this.totalItems,
    required this.totalWears,
    required this.colorPalette,
    required this.underutilizedItems,
    required this.realVsStarterRatio,
    this.averageCostPerWear,
    this.mostWornCategory,
  });

  final int totalItems;
  final int totalWears;
  final double? averageCostPerWear;
  final List<IntelligenceColorBucket> colorPalette;
  final List<IntelligenceUnderutilized> underutilizedItems;
  final String? mostWornCategory;
  final double realVsStarterRatio;

  factory IntelligenceReport.fromJson(Map<String, dynamic> json) {
    return IntelligenceReport(
      totalItems: json['total_items'] as int? ?? 0,
      totalWears: json['total_wears'] as int? ?? 0,
      averageCostPerWear: (json['average_cost_per_wear'] as num?)?.toDouble(),
      colorPalette: (json['color_palette'] as List<dynamic>? ?? const [])
          .map((e) => IntelligenceColorBucket.fromJson(e as Map<String, dynamic>))
          .toList(),
      underutilizedItems:
          (json['underutilized_items'] as List<dynamic>? ?? const [])
              .map((e) =>
                  IntelligenceUnderutilized.fromJson(e as Map<String, dynamic>))
              .toList(),
      mostWornCategory: json['most_worn_category'] as String?,
      realVsStarterRatio:
          (json['real_vs_starter_ratio'] as num?)?.toDouble() ?? 0,
    );
  }
}
