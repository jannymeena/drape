import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class CategoryFilterChips extends StatelessWidget {
  final List<String> categories;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const CategoryFilterChips({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final selected = i == selectedIndex;
          return Material(
            color: selected ? AppColors.espresso : AppColors.tanFixed,
            borderRadius: BorderRadius.circular(999),
            child: InkWell(
              onTap: () => onSelected(i),
              borderRadius: BorderRadius.circular(999),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Center(
                  child: Text(
                    categories[i],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: selected ? AppColors.white : AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
