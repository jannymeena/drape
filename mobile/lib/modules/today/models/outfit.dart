/// Mirrors the backend `OutfitResponse` / `OutfitItem` / `WeatherContext`
/// (`app/schemas/outfit.py`). `image_url` is null by design — the client
/// composes the visual from the items' `primary_image_url` (2×2 grid).
library;

import '../../../shared/config/api_config.dart';

class OutfitItem {
  const OutfitItem({
    required this.itemId,
    required this.name,
    required this.category,
    this.primaryImageUrl,
    this.colorName,
    this.formality,
    this.whyItWorks,
    this.isStarterWardrobe = false,
  });

  final String itemId;
  final String name;
  final String category;
  final String? primaryImageUrl;
  final String? colorName;
  final String? formality;
  final String? whyItWorks;
  final bool isStarterWardrobe;

  factory OutfitItem.fromJson(Map<String, dynamic> json) {
    return OutfitItem(
      itemId: json['item_id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      primaryImageUrl: ApiConfig.resolveImageUrl(json['primary_image_url'] as String?),
      colorName: json['color_name'] as String?,
      formality: json['formality'] as String?,
      whyItWorks: json['why_it_works'] as String?,
      isStarterWardrobe: json['is_starter_wardrobe'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'name': name,
        'category': category,
        'primary_image_url': primaryImageUrl,
        'color_name': colorName,
        'formality': formality,
        'why_it_works': whyItWorks,
        'is_starter_wardrobe': isStarterWardrobe,
      };
}

class WeatherContext {
  const WeatherContext({
    required this.tempC,
    required this.feelsLikeC,
    required this.condition,
    this.humidityPct,
    this.windKph,
  });

  final double tempC;
  final double feelsLikeC;
  final String condition;
  final int? humidityPct;
  final double? windKph;

  factory WeatherContext.fromJson(Map<String, dynamic> json) {
    return WeatherContext(
      tempC: (json['temp_c'] as num).toDouble(),
      feelsLikeC: (json['feels_like_c'] as num).toDouble(),
      condition: json['condition'] as String,
      humidityPct: json['humidity_pct'] as int?,
      windKph: (json['wind_kph'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'temp_c': tempC,
        'feels_like_c': feelsLikeC,
        'condition': condition,
        'humidity_pct': humidityPct,
        'wind_kph': windKph,
      };
}

class Outfit {
  const Outfit({
    required this.id,
    required this.occasion,
    required this.items,
    required this.usingStarterWardrobe,
    required this.isLogged,
    required this.wornCount,
    this.isFavorite = false,
    this.imageUrl,
    this.aiReasoningShort,
    this.aiReasoningFull,
    this.compatibilityScore,
    this.weatherContext,
    this.loggedAt,
  });

  final String id;
  final String occasion; // backend literal: work | casual | gym | date_night | other
  final List<OutfitItem> items;
  final bool usingStarterWardrobe;
  final bool isLogged;
  final int wornCount;
  final bool isFavorite;
  final String? imageUrl;
  final String? aiReasoningShort;
  final String? aiReasoningFull;
  final int? compatibilityScore;
  final WeatherContext? weatherContext;
  final DateTime? loggedAt;

  /// Up to four item images for the client-side 2×2 grid (nulls allowed).
  List<String?> get gridImageUrls => items.map((i) => i.primaryImageUrl).toList();

  /// Used to fold the `POST /outfits/{id}/log` result back into the dashboard
  /// without a full refetch (the log endpoint returns streak data, not the
  /// whole outfit, so we patch the flags locally).
  Outfit copyWith({
    bool? isLogged,
    DateTime? loggedAt,
    int? wornCount,
    List<OutfitItem>? items,
    int? compatibilityScore,
    bool? isFavorite,
  }) {
    return Outfit(
      id: id,
      occasion: occasion,
      items: items ?? this.items,
      usingStarterWardrobe: usingStarterWardrobe,
      isLogged: isLogged ?? this.isLogged,
      wornCount: wornCount ?? this.wornCount,
      isFavorite: isFavorite ?? this.isFavorite,
      imageUrl: imageUrl,
      aiReasoningShort: aiReasoningShort,
      aiReasoningFull: aiReasoningFull,
      compatibilityScore: compatibilityScore ?? this.compatibilityScore,
      weatherContext: weatherContext,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  /// Human-friendly occasion label (e.g. `date_night` → "Date Night").
  String get occasionLabel => occasion
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  factory Outfit.fromJson(Map<String, dynamic> json) {
    final weather = json['weather_context'] as Map<String, dynamic>?;
    return Outfit(
      id: json['id'] as String,
      occasion: json['occasion'] as String,
      items: (json['items'] as List<dynamic>)
          .map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      usingStarterWardrobe: json['using_starter_wardrobe'] as bool? ?? false,
      isLogged: json['is_logged'] as bool? ?? false,
      wornCount: json['worn_count'] as int? ?? 0,
      isFavorite: json['is_favorite'] as bool? ?? false,
      imageUrl: ApiConfig.resolveImageUrl(json['image_url'] as String?),
      aiReasoningShort: json['ai_reasoning_short'] as String?,
      aiReasoningFull: json['ai_reasoning_full'] as String?,
      compatibilityScore: json['compatibility_score'] as int?,
      weatherContext: weather == null ? null : WeatherContext.fromJson(weather),
      loggedAt: json['logged_at'] == null
          ? null
          : DateTime.parse(json['logged_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'occasion': occasion,
        'items': items.map((i) => i.toJson()).toList(),
        'using_starter_wardrobe': usingStarterWardrobe,
        'is_logged': isLogged,
        'worn_count': wornCount,
        'is_favorite': isFavorite,
        'image_url': imageUrl,
        'ai_reasoning_short': aiReasoningShort,
        'ai_reasoning_full': aiReasoningFull,
        'compatibility_score': compatibilityScore,
        'weather_context': weatherContext?.toJson(),
        'logged_at': loggedAt?.toIso8601String(),
      };
}
