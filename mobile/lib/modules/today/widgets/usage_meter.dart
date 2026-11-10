import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'outfit_card.dart';

/// "2 of 10 outfit ideas used this week · Get unlimited" — the always-on
/// free-tier meter under the outfit carousel (replaces the old 75%+ banner).
/// The counters are the backend's weekly ones (`GET /usage/current-week`).
class UsageMeter extends StatelessWidget {
  final int used;
  final int limit;
  final VoidCallback onUpgrade;

  const UsageMeter({
    super.key,
    required this.used,
    required this.limit,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final blocked = limit > 0 && used >= limit;
    final fraction = limit <= 0 ? 0.0 : (used / limit).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: todayCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 16, color: AppColors.espressoDark),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  blocked
                      ? 'All $limit outfit ideas used this week'
                      : '$used of $limit outfit ideas used this week',
                  style: text.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ),
              GestureDetector(
                onTap: onUpgrade,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Get unlimited',
                    style: text.labelMedium?.copyWith(
                      color: AppColors.espressoDark,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.espressoDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 4,
              backgroundColor: AppColors.sand,
              valueColor: AlwaysStoppedAnimation(
                blocked ? AppColors.error : AppColors.espresso,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
