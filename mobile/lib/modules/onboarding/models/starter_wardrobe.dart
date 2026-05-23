/// DTOs for the starter-wardrobe endpoints.
///
/// The onboarding flow assigns a starter wardrobe so a brand-new user has
/// outfits before adding their own items; the backend auto-picks a template
/// from the user's shopping_style + age_range (neutral default otherwise) and
/// materializes its items into `/wardrobe`.
library;

/// One row of `GET /starter-wardrobe/templates` (the browsable catalogue).
class StarterTemplate {
  const StarterTemplate({
    required this.id,
    required this.templateId,
    required this.name,
    required this.totalItems,
    this.gender,
    this.ageRange,
    this.styleProfile,
  });

  final String id; // UUID
  final String templateId; // slug, e.g. neutral_default
  final String name;
  final int totalItems;
  final String? gender;
  final String? ageRange;
  final String? styleProfile;

  factory StarterTemplate.fromJson(Map<String, dynamic> json) {
    return StarterTemplate(
      id: json['id'] as String,
      templateId: json['template_id'] as String,
      name: json['name'] as String,
      totalItems: json['total_items'] as int,
      gender: json['gender'] as String?,
      ageRange: json['age_range'] as String?,
      styleProfile: json['style_profile'] as String?,
    );
  }
}

/// Result of `POST /starter-wardrobe/assign` — the chosen template slug, how
/// many items were materialized this call, and the live starter-item count.
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
