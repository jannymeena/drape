import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// "Added to wishlist!" confirmation toast — a styled SnackBar.
void showWishlistToast(BuildContext context, {bool added = true}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.sage,
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(added ? Icons.check_circle : Icons.remove_circle_outline,
                color: AppColors.white, size: 18),
            const SizedBox(width: 10),
            Text(
              added ? 'Added to wishlist!' : 'Removed from wishlist',
              style: const TextStyle(
                color: AppColors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
}
