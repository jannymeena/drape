import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mobile/modules/wardrobe/image_compress.dart';

Uint8List _png(int w, int h) =>
    Uint8List.fromList(img.encodePng(img.Image(width: w, height: h)));

void main() {
  test('landscape larger than the cap is scaled so the long edge is 1024', () {
    final out = compressUploadBytes(_png(3000, 2000));
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, kMaxUploadEdge);
    // Aspect ratio preserved (3:2 → ~683 tall).
    expect((decoded.height - (kMaxUploadEdge * 2 / 3)).abs(), lessThanOrEqualTo(1));
  });

  test('portrait larger than the cap is scaled so the long edge is 1024', () {
    final out = compressUploadBytes(_png(2000, 3000));
    final decoded = img.decodeImage(out)!;
    expect(decoded.height, kMaxUploadEdge);
    expect((decoded.width - (kMaxUploadEdge * 2 / 3)).abs(), lessThanOrEqualTo(1));
  });

  test('image already within the cap is not upscaled', () {
    final out = compressUploadBytes(_png(400, 300));
    final decoded = img.decodeImage(out)!;
    expect(decoded.width, 400);
    expect(decoded.height, 300);
  });

  test('output is always JPEG', () {
    final out = compressUploadBytes(_png(1500, 1500));
    // JPEG SOI marker.
    expect(out[0], 0xFF);
    expect(out[1], 0xD8);
    expect(img.decodeJpg(out), isNotNull);
  });

  test('undecodable bytes are returned unchanged', () {
    final junk = Uint8List.fromList([0, 1, 2, 3, 4]);
    expect(compressUploadBytes(junk), same(junk));
  });
}
