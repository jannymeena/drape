/// DTOs for the starter-wardrobe endpoints.
///
/// The onboarding flow assigns a starter wardrobe so a brand-new user has
/// outfits before adding their own items; the backend picks a capsule of AWIN
/// products for the user's shopping_style and materializes it into
/// `/wardrobe` (each item links to its product for the "Buy" pill).
library;

/// Result of `POST /starter-wardrobe/assign` — the capsule slug, how many
/// items were materialized this call, and the live starter-item count.
class StarterWardrobeResult {
  const StarterWardrobeResult({
    required this.templateId,
    required this.itemsMaterialized,
    required this.swapped,
    required this.starterItemsCount,
  });

  final String templateId;
  final int itemsMaterialized;
  final bool swapped;
  final int starterItemsCount;

  factory StarterWardrobeResult.fromJson(Map<String, dynamic> json) {
    final transition = json['transition'] as Map<String, dynamic>?;
    return StarterWardrobeResult(
      templateId: json['template_id'] as String,
      itemsMaterialized: json['items_materialized'] as int? ?? 0,
      swapped: json['swapped'] as bool? ?? false,
      starterItemsCount: transition?['starter_items_count'] as int? ?? 0,
    );
  }

  /// Best count to show the user: items added this call, else the live total.
  int get displayCount =>
      itemsMaterialized > 0 ? itemsMaterialized : starterItemsCount;
}
