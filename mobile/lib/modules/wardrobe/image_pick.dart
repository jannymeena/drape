import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/theme/app_colors.dart';
import 'image_compress.dart';

/// An image chosen by the user, ready to upload. Always JPEG after [_toPicked]'s
/// compression pass, so [mimeType] is `image/jpeg` (within the backend's allowed
/// jpeg/png/webp set, so multipart uploads don't 415).
class PickedImage {
  const PickedImage({
    required this.bytes,
    required this.filename,
    required this.mimeType,
  });

  final Uint8List bytes;
  final String filename;
  final String mimeType;
}

/// Strips any extension and gives `.jpg`, since [_toPicked] always re-encodes
/// to JPEG.
String _jpegName(String original) {
  final dot = original.lastIndexOf('.');
  final stem = dot > 0 ? original.substring(0, dot) : original;
  return '$stem.jpg';
}

Future<PickedImage?> _toPicked(XFile? file) async {
  if (file == null) return null;
  final raw = await file.readAsBytes();
  // Downscale to ≤1024px and re-encode JPEG q85 before upload — caps payload
  // size and AI vision cost, deterministically across formats/platforms.
  final bytes = await compressUpload(raw);
  return PickedImage(
    bytes: bytes,
    filename: _jpegName(file.name),
    mimeType: 'image/jpeg',
  );
}

/// Presents a camera/gallery chooser, then returns the picked image (null if
/// the user cancels at either step). Downscales + compresses to keep uploads
/// under the backend's 8 MiB cap.
Future<PickedImage?> pickWardrobeImage(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.sand,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined,
                color: AppColors.espresso),
            title: const Text('Take Photo'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined,
                color: AppColors.espresso),
            title: const Text('Choose from Library'),
            onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null) return null;
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 2000,
    imageQuality: 85,
  );
  return _toPicked(file);
}

/// Multi-pick from the gallery (batch upload). Returns an empty list if the
/// user cancels.
Future<List<PickedImage>> pickWardrobeImages() async {
  final files = await ImagePicker().pickMultiImage(
    maxWidth: 2000,
    imageQuality: 85,
  );
  final picked = <PickedImage>[];
  for (final f in files) {
    final p = await _toPicked(f);
    if (p != null) picked.add(p);
  }
  return picked;
}
