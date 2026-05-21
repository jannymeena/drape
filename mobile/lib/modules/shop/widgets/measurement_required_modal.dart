import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// Blocks Buy/Don't Buy until the user has body measurements.
/// Returns true if they chose "Complete Measurements Now".
Future<bool> showMeasurementRequiredModal(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.espressoDeep.withValues(alpha: 0.4),
    builder: (_) => const _MeasurementRequiredModal(),
  );
  return result ?? false;
}

class _MeasurementRequiredModal extends StatelessWidget {
  const _MeasurementRequiredModal();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.errorContainer,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.straighten, color: AppColors.error, size: 26),
            ),
            const SizedBox(height: 16),
            Text(
              'Measurements\nRequired',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              "Buy/Don't Buy uses your body measurements to predict fit and unlock outfit counts. Complete your measurements to use this feature.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const _Bullet('AI fit predictions'),
            const SizedBox(height: 10),
            const _Bullet('Size recommendations'),
            const SizedBox(height: 10),
            const _Bullet('Outfit unlock counts'),
            const SizedBox(height: 24),
            DrapeButton(
              label: 'Complete Measurements Now',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Maybe Later',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.ink,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String label;
  const _Bullet(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.sage, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }
}
