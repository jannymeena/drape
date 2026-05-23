import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/wardrobe/models/scan_detection.dart';

/// Parses a representative `POST /wardrobe/scan-item` payload (shape from
/// `ScanItemResponse` / `ScanDetection`).
void main() {
  test('ScanItemResult parses the detection + suggest flag', () {
    final r = ScanItemResult.fromJson({
      'detection': {
        'category': 'tops',
        'color': 'white',
        'pattern': 'solid',
        'formality': 'smart_casual',
        'confidence': 87,
      },
      'suggest_manual_entry': false,
    });

    expect(r.suggestManualEntry, isFalse);
    expect(r.detection.category, 'tops');
    expect(r.detection.color, 'white');
    expect(r.detection.confidence, 87);
    // "white" + "tops" → a usable default item name.
    expect(r.detection.suggestedName, 'White Tops');
  });

  test('warn case (50–69) keeps the detection with suggest_manual_entry', () {
    final r = ScanItemResult.fromJson({
      'detection': {
        'category': 'outerwear',
        'color': 'navy',
        'pattern': 'solid',
        'formality': 'casual',
        'confidence': 58,
      },
      'suggest_manual_entry': true,
    });

    expect(r.suggestManualEntry, isTrue);
    expect(r.detection.confidence, 58);
    expect(r.detection.suggestedName, 'Navy Outerwear');
  });

  test('BatchUploadResult parses mixed ok / low_confidence / error rows', () {
    final r = BatchUploadResult.fromJson({
      'results': [
        {
          'index': 0,
          'filename': 'a.jpg',
          'status': 'ok',
          'detection': {
            'category': 'tops',
            'color': 'white',
            'pattern': 'solid',
            'formality': 'casual',
            'confidence': 90,
          },
          'suggest_manual_entry': false,
        },
        {
          'index': 1,
          'status': 'low_confidence',
          'detection': {
            'category': 'shoes',
            'color': 'brown',
            'pattern': 'solid',
            'formality': 'smart_casual',
            'confidence': 55,
          },
          'suggest_manual_entry': true,
        },
        {
          'index': 2,
          'status': 'error',
          'error_code': 'ai_call_failed',
          'message': 'upstream hiccup',
        },
      ],
      'total': 3,
      'succeeded': 1,
      'low_confidence': 1,
      'errored': 1,
    });

    expect(r.results, hasLength(3));
    expect(r.succeeded, 1);
    expect(r.errored, 1);
    expect(r.results[0].detection!.category, 'tops');
    expect(r.results[1].suggestManualEntry, isTrue);
    expect(r.results[2].isError, isTrue);
    expect(r.results[2].detection, isNull);
    expect(r.results[2].errorCode, 'ai_call_failed');
  });
}
