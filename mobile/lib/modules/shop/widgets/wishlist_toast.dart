import 'package:flutter/material.dart';

import '../../../shared/widgets/drape_toast.dart';

/// "Added to wishlist!" confirmation toast.
void showWishlistToast(BuildContext context, {bool added = true}) {
  showDrapeToast(
    context,
    added ? 'Added to wishlist!' : 'Removed from wishlist',
    icon: added ? Icons.check_circle : Icons.remove_circle_outline,
  );
}
