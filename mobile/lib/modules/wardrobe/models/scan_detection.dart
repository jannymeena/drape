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
  });

  final String category;
  final String color;
  final String pattern;
  final String formality;
  final int confidence;

  /// A sensible default item name from the detection, e.g. "White Tops".
  String get suggestedName {
    final words = '$color $category'.trim().split(RegExp(r'\s+'));
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
    );
  }
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
