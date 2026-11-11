import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// One option in a [SegmentedTabs]; [count] (optional) shows beside it — in
/// an espresso badge when selected, plain grey otherwise.
class SegmentedTab {
  final String label;
  final int? count;
  const SegmentedTab(this.label, {this.count});
}

/// Warm pill switch with a raised white segment for the selection
/// (Favourites | History, Outfits | Items).
class SegmentedTabs extends StatelessWidget {
  final List<SegmentedTab> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  const SegmentedTabs({
    super.key,
    required this.tabs,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final (i, t) in tabs.indexed)
            Expanded(
              child: _Segment(
                tab: t,
                selected: i == selected,
                onTap: () => onSelect(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final SegmentedTab tab;
  final bool selected;
  final VoidCallback onTap;
  const _Segment({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final count = tab.count;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected
                ? const [
                    BoxShadow(
                      color: Color(0x0F2A1810),
                      blurRadius: 24,
                      spreadRadius: -4,
                      offset: Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tab.label,
                style: text.bodyLarge?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: selected ? AppColors.espresso : AppColors.inkSoft,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 8),
                selected
                    ? Container(
                        constraints: const BoxConstraints(minWidth: 20),
                        height: 20,
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: AppColors.espresso,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$count',
                          style: text.labelSmall?.copyWith(
                            color: AppColors.white,
                            letterSpacing: 0,
                          ),
                        ),
                      )
                    : Text(
                        '$count',
                        style: text.labelMedium?.copyWith(
                          color: AppColors.taupe,
                        ),
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
