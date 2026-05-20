import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

class MixMatchSheet extends StatefulWidget {
  const MixMatchSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.espressoDeep.withValues(alpha: 0.4),
      builder: (_) => const MixMatchSheet(),
    );
  }

  @override
  State<MixMatchSheet> createState() => _MixMatchSheetState();
}

class _MixMatchSheetState extends State<MixMatchSheet> {
  static const _occasions = ['Casual', 'Work', 'Date', 'Office Party', 'Christmas', 'Beach'];
  static const _categories = ['All', 'Tops', 'Bottoms', 'Shoes', 'Accessories'];
  static const _tops = <_MixItem>[
    _MixItem(name: 'Basic Tee', selected: true),
    _MixItem(name: 'Linen Shirt'),
    _MixItem(name: 'Knit Polo'),
    _MixItem(name: 'Denim'),
  ];
  static const _bottoms = <_MixItem>[
    _MixItem(name: 'Straight Jean'),
    _MixItem(name: 'Wide Pant', selected: true),
    _MixItem(name: 'Tailored Short'),
  ];
  static const _shoes = <_MixItem>[
    _MixItem(name: 'White Sneaker'),
    _MixItem(name: 'Loafers', selected: true),
  ];

  int _occasionIndex = 0;
  int _categoryIndex = 0;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.sand,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Mix & Match',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.taglineGrey),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Text(
                        'Dressing for:',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.taglineGrey,
                            ),
                      ),
                    ),
                    SizedBox(
                      height: 32,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _occasions.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => _OccasionPill(
                          label: _occasions[i],
                          selected: i == _occasionIndex,
                          onTap: () => setState(() => _occasionIndex = i),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.sageDim.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.auto_awesome,
                                  size: 14, color: AppColors.sage),
                              const SizedBox(width: 6),
                              Text(
                                'AI is styling your ${_occasions[_occasionIndex].toLowerCase()} vibe',
                                style: Theme.of(context).textTheme.labelMedium
                                    ?.copyWith(color: AppColors.sage),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _PreviewRow(),
                    const SizedBox(height: 18),
                    _CategoryTabs(
                      categories: _categories,
                      selected: _categoryIndex,
                      onSelected: (i) => setState(() => _categoryIndex = i),
                    ),
                    const SizedBox(height: 20),
                    _ItemRow(items: _tops),
                    const SizedBox(height: 16),
                    _ItemRow(items: _bottoms),
                    const SizedBox(height: 16),
                    _ItemRow(items: _shoes),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _ActionBar(
                onDiscard: () => Navigator.of(context).pop(),
                onWear: () {
                  debugPrint('mix: wear this');
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ),
      );
  }
}

class _OccasionPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OccasionPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.tanFixed,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected ? AppColors.white : AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  color: AppColors.ivoryDim,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.checkroom_outlined,
                    color: AppColors.taupeSoft,
                    size: 60,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MATCH SCORE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '87',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                              color: AppColors.sage,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      Text(
                        '/100',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.sage.withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                  Text(
                    'Perfect Harmony',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.sage,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryTabs extends StatelessWidget {
  final List<String> categories;
  final int selected;
  final ValueChanged<int> onSelected;

  const _CategoryTabs({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.taupeSoft),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(categories.length, (i) {
            final isSel = i == selected;
            return Padding(
              padding: const EdgeInsets.only(right: 22),
              child: GestureDetector(
                onTap: () => onSelected(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isSel ? AppColors.espresso : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                  child: Text(
                    categories[i],
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: isSel ? AppColors.espresso : AppColors.taupe,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _MixItem {
  final String name;
  final bool selected;
  const _MixItem({required this.name, this.selected = false});
}

class _ItemRow extends StatelessWidget {
  final List<_MixItem> items;
  const _ItemRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _MixItemTile(item: items[i]),
      ),
    );
  }
}

class _MixItemTile extends StatelessWidget {
  final _MixItem item;
  const _MixItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 76,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: item.selected ? AppColors.espresso : AppColors.taupeSoft,
                width: item.selected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(6),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.checkroom_outlined,
                      color: AppColors.taupeSoft,
                      size: 30,
                    ),
                  ),
                ),
                Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink,
                        letterSpacing: 0.2,
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
          if (item.selected)
            Positioned(
              top: -6,
              right: -6,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: AppColors.espresso,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.white, width: 2),
                ),
                child: const Icon(Icons.check, color: AppColors.white, size: 12),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final VoidCallback onDiscard;
  final VoidCallback onWear;
  const _ActionBar({required this.onDiscard, required this.onWear});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.taupeSoft)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(child: _SheetButton.outlined('Discard', onDiscard)),
            const SizedBox(width: 12),
            Expanded(child: _SheetButton.filled('Wear This', onWear)),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool filled;
  const _SheetButton.outlined(this.label, this.onPressed) : filled = false;
  const _SheetButton.filled(this.label, this.onPressed) : filled = true;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? AppColors.espresso : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.espresso, width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: filled ? AppColors.white : AppColors.espresso,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
