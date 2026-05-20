import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Small uppercase label used above outfit cards (e.g. "WORK", "CASUAL", "EVENING").
class OccasionBadge extends StatelessWidget {
  final String label;
  final Color? background;
  final Color? foreground;

  const OccasionBadge({
    super.key,
    required this.label,
    this.background,
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background ?? AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground ?? AppColors.inkSoft,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
