import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Amber banner shown on product pages when the user's measurements aren't
/// complete, so DRAPE can't predict fit. Tap routes to the measurement flow.
class MeasurementIncompleteBanner extends StatelessWidget {
  final VoidCallback onTap;

  const MeasurementIncompleteBanner({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF8EC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.straighten, color: Color(0xFFC8901C), size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Complete measurements for accurate fit predictions',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7D5A11),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            const Icon(Icons.arrow_forward, color: Color(0xFFC8901C), size: 16),
          ],
        ),
      ),
    );
  }
}
