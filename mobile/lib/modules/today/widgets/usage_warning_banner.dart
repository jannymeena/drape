import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

enum UsageLevel { soft, urgent, blocked }

/// Inline banner showing weekly generation usage with a CTA to upgrade.
///
/// - 75% (soft): warm cream background, gold accent
/// - 90% (urgent): same family, stronger emphasis on count
/// - 100% (blocked): error container colors + "Upgrade to continue"
class UsageWarningBanner extends StatelessWidget {
  final int used;
  final int total;
  final UsageLevel level;
  final VoidCallback? onUpgrade;

  const UsageWarningBanner({
    super.key,
    required this.used,
    required this.total,
    required this.level,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(level);
    final ctaLabel = level == UsageLevel.blocked ? 'Upgrade to continue' : 'Upgrade';

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(palette.icon, color: palette.accent, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$used of $total outfits used this week',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          GestureDetector(
            onTap: onUpgrade,
            child: Text(
              ctaLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  _BannerPalette _paletteFor(UsageLevel l) {
    switch (l) {
      case UsageLevel.soft:
        return const _BannerPalette(
          background: Color(0xFFFFF8EC),
          border: Color(0x4DC8901C),
          accent: Color(0xFFC8901C),
          text: Color(0xFF7D5A11),
          icon: Icons.info_outline,
        );
      case UsageLevel.urgent:
        return const _BannerPalette(
          background: Color(0xFFFDECDC),
          border: Color(0x66B8631C),
          accent: Color(0xFFB8631C),
          text: Color(0xFF6E380C),
          icon: Icons.warning_amber_rounded,
        );
      case UsageLevel.blocked:
        return _BannerPalette(
          background: AppColors.errorContainer,
          border: AppColors.error.withValues(alpha: 0.4),
          accent: AppColors.error,
          text: AppColors.onErrorContainer,
          icon: Icons.block,
        );
    }
  }
}

class _BannerPalette {
  final Color background;
  final Color border;
  final Color accent;
  final Color text;
  final IconData icon;
  const _BannerPalette({
    required this.background,
    required this.border,
    required this.accent,
    required this.text,
    required this.icon,
  });
}
