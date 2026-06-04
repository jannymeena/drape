import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Longest-edge cap and JPEG quality for uploads. Garment scans and avatars are
/// analyzed/displayed small, so 1024px @ q85 keeps detection quality while
/// cutting payloads (and AI vision cost) dramatically vs. a raw 12MP photo.
const int kMaxUploadEdge = 1024;
const int kUploadJpegQuality = 85;

/// Downscale to fit within [kMaxUploadEdge] on the longest side and re-encode as
/// JPEG q[kUploadJpegQuality]. Always re-encodes to JPEG (transparency isn't
/// needed for photos and the backend accepts jpeg), giving deterministic output
/// regardless of the source format or platform — unlike `image_picker`'s
/// best-effort `imageQuality`, which skips PNGs and varies by OS.
///
/// Pure/synchronous so it can run in an isolate via [compute] and be unit
/// tested without a platform channel. Returns the original bytes unchanged if
/// they can't be decoded (e.g. an exotic format) — the upload still proceeds.
Uint8List compressUploadBytes(Uint8List input) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } catch (_) {
    // `decodeImage` throws on unrecognized/corrupt data — fall through.
    decoded = null;
  }
  if (decoded == null) return input;

  final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
  final resized = longest > kMaxUploadEdge
      ? img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? kMaxUploadEdge : null,
          height: decoded.height > decoded.width ? kMaxUploadEdge : null,
        )
      : decoded;

  return img.encodeJpg(resized, quality: kUploadJpegQuality);
}

/// Async wrapper that offloads the decode/resize/encode to a background isolate
/// so a large photo never janks the UI thread.
Future<Uint8List> compressUpload(Uint8List input) {
  return compute(compressUploadBytes, input);
}
