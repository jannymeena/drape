import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// A wardrobe item's picture, as the card and the item screen show it.
///
/// - A ghost-mannequin shot (transparent) is laid whole on [backgroundAsset],
///   inside [shotPadding].
/// - The user's own photo fills the frame as it is: no background, no padding.
/// - While the mannequin shot is still being made ([processing]), the photo is
///   shown with a loading indicator over it.
class WardrobePicture extends StatelessWidget {
  const WardrobePicture({
    super.key,
    required this.imageUrl,
    required this.placeholder,
    this.mannequinShot = false,
    this.processing = false,
    this.backgroundAsset,
    this.shotPadding = EdgeInsets.zero,
  });

  final String? imageUrl;
  final Widget placeholder;
  final bool mannequinShot;
  final bool processing;
  final String? backgroundAsset;
  final EdgeInsets shotPadding;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    Widget picture;
    if (url == null) {
      picture = placeholder;
    } else if (mannequinShot) {
      picture = Stack(
        fit: StackFit.expand,
        children: [
          if (backgroundAsset != null)
            Image.asset(backgroundAsset!, fit: BoxFit.cover),
          Padding(
            padding: shotPadding,
            child: CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              errorWidget: (_, _, _) => placeholder,
            ),
          ),
        ],
      );
    } else {
      picture = CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        errorWidget: (_, _, _) => placeholder,
      );
    }
    if (!processing) return picture;
    return Stack(
      fit: StackFit.expand,
      children: [picture, const WardrobePictureProcessing()],
    );
  }
}

/// The loading indicator laid over a photo while its mannequin shot is made.
class WardrobePictureProcessing extends StatelessWidget {
  const WardrobePictureProcessing({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Preparing the picture',
      child: ColoredBox(
        color: AppColors.ivory.withValues(alpha: 0.45),
        child: const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.espresso,
            ),
          ),
        ),
      ),
    );
  }
}
