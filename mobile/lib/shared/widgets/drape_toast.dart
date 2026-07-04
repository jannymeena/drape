import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Styled confirmation toast — the floating sage pill from the
/// `item_added_success_toast` mockup: leading icon, bold white message,
/// optional lighter trailing detail (e.g. "27/30 items").
///
/// For success confirmations only; errors keep the plain default SnackBar.
void showDrapeToast(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle,
  String? trailing,
  Color background = AppColors.sage,
  Duration duration = const Duration(seconds: 2),
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: background,
        duration: duration,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(icon, color: AppColors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              Text(
                trailing,
                style: TextStyle(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
}
