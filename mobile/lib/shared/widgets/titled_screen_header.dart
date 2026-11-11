import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Header for screens pushed from Today (Notifications, Favourites): back
/// arrow on the left, [title] centred on the screen in the "Plan your week"
/// style, an optional action icon, and (with [onProfile]) the profile avatar
/// on the right.
class TitledScreenHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback? onProfile;

  /// e.g. settings (Notifications) or filter (Favourites).
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;

  const TitledScreenHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.onProfile,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Centred on the screen, not between the side controls.
          Text(title, style: AppTypography.screenTitle),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    size: 22,
                    color: AppColors.ink,
                  ),
                  onPressed: onBack,
                ),
                const Spacer(),
                if (actionIcon != null)
                  IconButton(
                    tooltip: actionTooltip,
                    icon: Icon(actionIcon, size: 22, color: AppColors.ink),
                    onPressed: onAction,
                  ),
                if (onProfile != null) ...[
                  const SizedBox(width: 4),
                  Semantics(
                    button: true,
                    label: 'Profile',
                    child: InkResponse(
                      onTap: onProfile,
                      radius: 22,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.espressoDark,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.person_outline,
                          size: 18,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
