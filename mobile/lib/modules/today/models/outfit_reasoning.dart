/// Mirrors the backend `OutfitReasoningResponse` / `ReasoningItem`
/// (`app/schemas/outfit.py`), returned by `GET /outfits/{id}/reasoning`.
///
/// `fullText` is the long-form narrative (may be null for older rows);
/// `compatibilityLabel` is a server-derived band ("High compatibility" …) and
/// `factors` is the list of headline reasons the look holds together.
library;

import '../../../shared/config/api_config.dart';

class ReasoningItem {
  const ReasoningItem({
    required this.itemId,
    required this.name,
    this.whyItWorks,
    this.imageUrl,
  });

  final String itemId;
  final String name;
  final String? whyItWorks;
  final String? imageUrl;

  factory ReasoningItem.fromJson(Map<String, dynamic> json) {
    return ReasoningItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      whyItWorks: json['why_it_works'] as String?,
      imageUrl: ApiConfig.resolveImageUrl(json['image_url'] as String?),
    );
  }
}

class OutfitReasoning {
  const OutfitReasoning({
    required this.outfitId,
    required this.items,
    required this.compatibilityLabel,
    required this.factors,
    this.fullText,
    this.compatibilityScore,
  });

  final String outfitId;
  final String? fullText;
  final List<ReasoningItem> items;
  final int? compatibilityScore;
  final String compatibilityLabel;
  final List<String> factors;

  factory OutfitReasoning.fromJson(Map<String, dynamic> json) {
    return OutfitReasoning(
      outfitId: json['outfit_id'] as String,
      fullText: json['full_text'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => ReasoningItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      compatibilityScore: json['compatibility_score'] as int?,
      compatibilityLabel: json['compatibility_label'] as String? ?? '',
      factors: (json['factors'] as List<dynamic>? ?? const [])
          .map((e) => e as String)
          .toList(),
    );
  }
}
