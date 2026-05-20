import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Settings group: uppercase taupe header + rounded white card holding the rows.
class SettingsSection extends StatelessWidget {
  final String? title;
  final Color? titleColor;
  final List<Widget> rows;
  final Color? background;

  const SettingsSection({
    super.key,
    this.title,
    this.titleColor,
    required this.rows,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: titleColor ?? AppColors.taupe,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
        Container(
          decoration: BoxDecoration(
            color: background ?? AppColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Column(
            children: [
              for (int i = 0; i < rows.length; i++) ...[
                rows[i],
                if (i < rows.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.taupeSoft.withValues(alpha: 0.3),
                    indent: 62,
                    endIndent: 14,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
