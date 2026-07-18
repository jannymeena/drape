import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// Returns true if the user chose "Finish Later" (exit), false if "Keep Going".
Future<bool> showSaveProgressDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.black.withValues(alpha: 0.4),
    builder: (_) => const _SaveProgressDialog(),
  );
  return result ?? false;
}

class _SaveProgressDialog extends StatelessWidget {
  const _SaveProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Save Your Progress?',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'You can finish your style measurements anytime in Settings → Your ZOURA Profile.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            DrapeButton(
              label: 'Finish Later',
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 8),
            DrapeButton.outlined(
              label: 'Keep Going',
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}
