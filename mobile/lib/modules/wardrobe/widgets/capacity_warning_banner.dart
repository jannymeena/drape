import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

enum CapacityLevel { soft, urgent, blocked }

/// Wardrobe capacity warning — shown above the grid when usage trends near
/// the cap (22+ soft, 27+ urgent, 30 hard block).
class CapacityWarningBanner extends StatelessWidget {
  final int used;
  final int total;
  final CapacityLevel level;
  final VoidCallback? onUpgrade;
  final VoidCallback? onDismiss;

  const CapacityWarningBanner({
    super.key,
    required this.used,
    required this.total,
    required this.level,
    this.onUpgrade,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _palette(level);
    final remaining = total - used;

    final headline = switch (level) {
      CapacityLevel.soft => '$used of $total items used. You have $remaining slots left.',
      CapacityLevel.urgent =>
        '$used of $total items used. Only $remaining slots left.',
      CapacityLevel.blocked => 'Wardrobe limit reached ($used/$total items)',
    };

    final cta = level == CapacityLevel.blocked
        ? 'View Premium Plans'
        : 'Upgrade to Pro for unlimited items →';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(palette.icon, color: palette.accent, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  headline,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.text,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              if (onDismiss != null)
                GestureDetector(
                  onTap: onDismiss,
                  child:
                      Icon(Icons.close, color: palette.accent, size: 16),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onUpgrade,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: palette.cta,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                cta,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _Palette _palette(CapacityLevel l) {
    switch (l) {
      case CapacityLevel.soft:
        return const _Palette(
          background: Color(0xFFFFF8EC),
          border: Color(0x4DC8901C),
          accent: Color(0xFFC8901C),
          text: Color(0xFF7D5A11),
          cta: AppColors.gold,
          icon: Icons.warning_amber_rounded,
        );
      case CapacityLevel.urgent:
        return const _Palette(
          background: Color(0xFFFDECDC),
          border: Color(0x66B8631C),
          accent: Color(0xFFB8631C),
          text: Color(0xFF6E380C),
          cta: AppColors.gold,
          icon: Icons.warning_amber_rounded,
        );
      case CapacityLevel.blocked:
        return _Palette(
          background: AppColors.errorContainer,
          border: AppColors.error.withValues(alpha: 0.4),
          accent: AppColors.error,
          text: AppColors.onErrorContainer,
          cta: AppColors.espresso,
          icon: Icons.block,
        );
    }
  }
}

class _Palette {
  final Color background;
  final Color border;
  final Color accent;
  final Color text;
  final Color cta;
  final IconData icon;

  const _Palette({
    required this.background,
    required this.border,
    required this.accent,
    required this.text,
    required this.cta,
    required this.icon,
  });
}
