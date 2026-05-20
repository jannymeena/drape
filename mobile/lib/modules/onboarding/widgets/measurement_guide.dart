import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Dual-card illustrated guide: left = how to measure (line diagram),
/// right = avatar forming preview. Placeholders for now; real art lands later.
class MeasurementGuide extends StatelessWidget {
  final String bodyPart;

  const MeasurementGuide({super.key, required this.bodyPart});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                border: Border.all(color: AppColors.taupeSoft),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.straighten,
                size: 48,
                color: AppColors.taupe.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.tanFixed,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  const Center(
                    child: Icon(
                      Icons.person_outline,
                      size: 80,
                      color: AppColors.espresso,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Text(
                        'FORMING AVATAR',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.espressoDark,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
