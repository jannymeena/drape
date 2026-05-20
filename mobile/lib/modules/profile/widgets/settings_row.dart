import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Standard settings list row: circular icon + label + optional subtitle + trailing.
/// Used as a child of [SettingsSection].
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? iconBackground;
  final Color? labelColor;
  final bool danger;

  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.iconColor,
    this.iconBackground,
    this.labelColor,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = danger ? AppColors.error : (labelColor ?? AppColors.ink);
    final iconFg = danger ? AppColors.error : (iconColor ?? AppColors.espresso);
    final iconBg = iconBackground ?? AppColors.ivoryWarm;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconFg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: fg,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            trailing ??
                const Icon(Icons.chevron_right, color: AppColors.taupe, size: 22),
          ],
        ),
      ),
    );
  }
}
