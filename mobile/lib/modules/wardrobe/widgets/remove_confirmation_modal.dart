import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class RemoveConfirmationModal extends StatelessWidget {
  final String itemName;
  final VoidCallback onConfirm;

  const RemoveConfirmationModal({
    super.key,
    required this.itemName,
    required this.onConfirm,
  });

  static Future<bool> show(
    BuildContext context, {
    required String itemName,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.espressoDeep.withValues(alpha: 0.6),
      builder: (ctx) => RemoveConfirmationModal(
        itemName: itemName,
        onConfirm: () => Navigator.of(ctx).pop(true),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      backgroundColor: AppColors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.delete_outline,
                  color: AppColors.error, size: 22),
            ),
            const SizedBox(height: 16),
            Text(
              'Remove this item?',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "This will remove '$itemName' from your wardrobe and any outfits that include it.",
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'This cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _DialogButton(
                    label: 'Cancel',
                    onPressed: () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DialogButton(
                    label: 'Remove Item',
                    onPressed: onConfirm,
                    danger: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool danger;

  const _DialogButton({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = danger ? AppColors.error : AppColors.white;
    final fg = danger ? AppColors.white : AppColors.ink;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: danger
            ? BorderSide.none
            : const BorderSide(color: AppColors.taupeSoft),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          height: 48,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
