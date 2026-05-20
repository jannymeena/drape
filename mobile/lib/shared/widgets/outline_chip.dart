import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OutlineChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData? icon;

  const OutlineChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? AppColors.espresso : AppColors.white;
    final fg = selected ? AppColors.white : AppColors.ink;
    final border = selected ? AppColors.espresso : AppColors.taupeSoft;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
