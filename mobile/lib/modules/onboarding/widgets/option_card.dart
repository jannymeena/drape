import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

enum OptionSelector { radio, checkbox }

class OptionCard extends StatelessWidget {
  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool selected;
  final VoidCallback onTap;
  final OptionSelector selector;

  const OptionCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.selector = OptionSelector.radio,
  });

  @override
  Widget build(BuildContext context) {
    final border = selected ? AppColors.espresso : AppColors.taupeSoft;
    final width = selected ? 2.0 : 1.0;
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: border, width: width),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: AppColors.espresso, size: 22),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: AppColors.inkSoft, size: 20)
              else
                _Selector(selector: selector, selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _Selector extends StatelessWidget {
  final OptionSelector selector;
  final bool selected;
  const _Selector({required this.selector, required this.selected});

  @override
  Widget build(BuildContext context) {
    if (selector == OptionSelector.checkbox) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: selected ? AppColors.espresso : AppColors.white,
          border: Border.all(
            color: selected ? AppColors.espresso : AppColors.taupeSoft,
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: selected
            ? const Icon(Icons.check, color: AppColors.white, size: 16)
            : null,
      );
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        border: Border.all(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
          width: 1.5,
        ),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: AppColors.espresso,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}
