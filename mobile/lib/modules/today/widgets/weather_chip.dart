import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Today dashboard weather widget — temperature + condition + hint + chevron.
class WeatherChip extends StatelessWidget {
  final String temperature;
  final String condition;
  final String hint;
  final String? location;
  final IconData icon;
  final VoidCallback? onTap;

  const WeatherChip({
    super.key,
    required this.temperature,
    required this.condition,
    required this.hint,
    this.location,
    this.icon = Icons.cloud_outlined,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.tanFixed.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 26),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$temperature • $condition',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.espresso,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      hint,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (location != null) ...[
                const SizedBox(width: 8),
                Text(
                  location!.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.inkSoft,
                        letterSpacing: 1.2,
                      ),
                ),
              ] else
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.espresso,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
