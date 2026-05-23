import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../shared/theme/app_colors.dart';

/// An image chosen by the user, ready to upload. [mimeType] is constrained to
/// the backend's allowed set (jpeg/png/webp) so multipart uploads don't 415.
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

const _allowedMime = {'image/jpeg', 'image/png', 'image/webp'};

String _mimeFromName(String name) {
  final n = name.toLowerCase();
  if (n.endsWith('.png')) return 'image/png';
  if (n.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

Future<PickedImage?> _toPicked(XFile? file) async {
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  var mime = file.mimeType;
  if (mime == null || !_allowedMime.contains(mime)) {
    mime = _mimeFromName(file.name);
  }
  return PickedImage(bytes: bytes, filename: file.name, mimeType: mime);
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
