import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

enum DrapeNavDestination { today, wardrobe, shop, profile }

class DrapeBottomNav extends StatelessWidget {
  final DrapeNavDestination current;
  final ValueChanged<DrapeNavDestination> onSelected;

  const DrapeBottomNav({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.ivory,
        border: Border(top: BorderSide(color: AppColors.taupeSoft, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Item(
                label: 'TODAY',
                icon: Icons.calendar_today_outlined,
                selected: current == DrapeNavDestination.today,
                onTap: () => onSelected(DrapeNavDestination.today),
              ),
              _Item(
                label: 'WARDROBE',
                icon: Icons.checkroom_outlined,
                selected: current == DrapeNavDestination.wardrobe,
                onTap: () => onSelected(DrapeNavDestination.wardrobe),
              ),
              _Item(
                label: 'SHOP',
                icon: Icons.shopping_bag_outlined,
                selected: current == DrapeNavDestination.shop,
                onTap: () => onSelected(DrapeNavDestination.shop),
              ),
              _Item(
                label: 'PROFILE',
                icon: Icons.person_outline,
                selected: current == DrapeNavDestination.profile,
                onTap: () => onSelected(DrapeNavDestination.profile),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _Item({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.espresso : AppColors.taupe;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    letterSpacing: 1.2,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
