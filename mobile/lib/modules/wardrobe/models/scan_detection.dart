/// Mirrors the backend scanner shapes (`app/schemas/scanner.py`):
/// `ScanDetection` + `ScanItemResponse`. Confidence is 0–100; the backend
/// auto-accepts ≥70, warns (200 + `suggest_manual_entry`) at 50–69, and 400s
/// (`low_confidence`) below 50 — so a *successful* scan here is always ≥50.
library;

class ScanDetection {
  const ScanDetection({
    required this.category,
    required this.color,
    required this.pattern,
    required this.formality,
    required this.confidence,
    this.subcategory,
    this.model,
  });

  final String category;

  /// Garment type within the category ("ankle boots", "midi dress"); null
  /// when the AI didn't say.
  final String? subcategory;
  final String color;
  final String pattern;
  final String formality;
  final int confidence;

  /// The vision model that produced this detection (null from mocks).
  final String? model;

  /// A sensible default item name from the detection, e.g. "Black Ankle
  /// Boots" (or "White Tops" when there's no garment type).
  String get suggestedName =>
      nameFor(color: color, category: category, subcategory: subcategory);

  /// Default item name: colour + garment type, falling back to the category,
  /// e.g. "Navy Blazer" / "Navy Outerwear".
  static String nameFor({
    required String color,
    required String category,
    String? subcategory,
  }) {
    final kind = (subcategory ?? '').trim().isEmpty ? category : subcategory;
    final words = '$color $kind'.trim().split(RegExp(r'\s+'));
    return words
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  factory ScanDetection.fromJson(Map<String, dynamic> json) {
    return ScanDetection(
      category: json['category'] as String,
      color: json['color'] as String,
      pattern: json['pattern'] as String,
      formality: json['formality'] as String,
      confidence: json['confidence'] as int? ?? 0,
      subcategory: json['subcategory'] as String?,
      model: json['model'] as String?,
    );
  }

  /// Echoed untouched as `ai_detection` when the item is created, so the
  /// backend can measure how often users correct the AI.
  Map<String, dynamic> toJson() => {
        'category': category,
        'color': color,
        'pattern': pattern,
        'formality': formality,
        'confidence': confidence,
        if (subcategory != null) 'subcategory': subcategory,
        if (model != null) 'model': model,
      };
}

class ScanItemResult {
  const ScanItemResult({
    required this.detection,
    required this.suggestManualEntry,
  });

  final ScanDetection detection;
  final bool suggestManualEntry;

  factory ScanItemResult.fromJson(Map<String, dynamic> json) {
    return ScanItemResult(
      detection:
          ScanDetection.fromJson(json['detection'] as Map<String, dynamic>),
      suggestManualEntry: json['suggest_manual_entry'] as bool? ?? false,
    );
  }
}

/// One row of `POST /wardrobe/batch-upload` (mirrors `BatchUploadItem`).
/// [status] discriminates the optional fields: `ok`/`low_confidence` carry a
/// [detection]; `error` carries [errorCode]/[message] instead. [index] maps the
/// row back to the picked image it came from.
class BatchUploadItem {
  const BatchUploadItem({
    required this.index,
    required this.status,
    this.filename,
    this.detection,
    this.suggestManualEntry = false,
    this.errorCode,
    this.message,
  });

  final int index;
  final String status; // ok | low_confidence | error
  final String? filename;
  final ScanDetection? detection;
  final bool suggestManualEntry;
  final String? errorCode;
  final String? message;

  bool get isError => status == 'error';

  factory BatchUploadItem.fromJson(Map<String, dynamic> json) {
    final detection = json['detection'] as Map<String, dynamic>?;
    return BatchUploadItem(
      index: json['index'] as int? ?? 0,
      status: json['status'] as String? ?? 'error',
      filename: json['filename'] as String?,
      detection: detection == null ? null : ScanDetection.fromJson(detection),
      suggestManualEntry: json['suggest_manual_entry'] as bool? ?? false,
      errorCode: json['error_code'] as String?,
      message: json['message'] as String?,
    );
  }
}

class BatchUploadResult {
  const BatchUploadResult({
    required this.results,
    required this.total,
    required this.succeeded,
    required this.lowConfidence,
    required this.errored,
  });

  final List<BatchUploadItem> results;
  final int total;
  final int succeeded;
  final int lowConfidence;
  final int errored;

  factory BatchUploadResult.fromJson(Map<String, dynamic> json) {
    return BatchUploadResult(
      results: (json['results'] as List<dynamic>? ?? const [])
          .map((e) => BatchUploadItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      succeeded: json['succeeded'] as int? ?? 0,
      lowConfidence: json['low_confidence'] as int? ?? 0,
      errored: json['errored'] as int? ?? 0,
    );
  }
}
