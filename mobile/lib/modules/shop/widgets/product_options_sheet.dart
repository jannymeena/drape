import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'wishlist_toast.dart';

/// Bottom sheet listing buyable products that fill a wardrobe gap.
Future<void> showProductOptionsSheet(
  BuildContext context, {
  required String title,
  required int unlockCount,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.espressoDeep.withValues(alpha: 0.4),
    builder: (_) => _ProductOptionsSheet(title: title, unlockCount: unlockCount),
  );
}

class _Option {
  final String name;
  final String brand;
  final String price;
  final String? oldPrice;
  final bool onSale;
  final String matches;
  const _Option({
    required this.name,
    required this.brand,
    required this.price,
    required this.matches,
    this.oldPrice,
    this.onSale = false,
  });
}

class _ProductOptionsSheet extends StatefulWidget {
  final String title;
  final int unlockCount;
  const _ProductOptionsSheet({required this.title, required this.unlockCount});

  @override
  State<_ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<_ProductOptionsSheet> {
  int _filter = 0;
  static const _filters = ['All', 'Best match', 'Under \$100', 'On sale'];

  static const _options = <_Option>[
    _Option(name: 'Navy Blazer', brand: 'H&M', price: r'$89.99', matches: 'Matches 8 outfits'),
    _Option(name: 'Navy Blazer', brand: 'Zara', price: r'$79.00', oldPrice: r'$119', onSale: true, matches: 'Matches 6 outfits'),
    _Option(name: 'Structured Navy Blazer', brand: 'Club Monaco', price: r'$185.00', matches: 'Matches 12 outfits'),
    _Option(name: 'Relaxed Blazer', brand: 'ASOS', price: r'$64.00', matches: 'Matches 4 outfits'),
  ];

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, controller) => Container(
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
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title,
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.auto_awesome,
                                color: AppColors.gold, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Unlocks ${widget.unlockCount} outfits in your wardrobe',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.gold,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.taglineGrey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filters.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _FilterPill(
                  label: _filters[i],
                  selected: i == _filter,
                  onTap: () => setState(() => _filter = i),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                itemCount: _options.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (_, i) => _OptionRow(
                  option: _options[i],
                  onTap: () {
                    Navigator.of(context).pop();
                    showWishlistToast(context);
                  },
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Text(
                  'ZOURA earns a small commission on purchases. Your price is never affected.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterPill({
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
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

class _OptionRow extends StatelessWidget {
  final _Option option;
  final VoidCallback onTap;
  const _OptionRow({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.checkroom_outlined,
                        color: AppColors.taupeSoft),
                  ),
                  if (option.onSale)
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: const BoxDecoration(
                          color: AppColors.error,
                          borderRadius:
                              BorderRadius.only(topLeft: Radius.circular(8)),
                        ),
                        child: Text(
                          'SALE',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.name,
                        style: Theme.of(context).textTheme.titleSmall),
                    Text(option.brand,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (option.oldPrice != null) ...[
                          Text(
                            option.oldPrice!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.taupe,
                                  decoration: TextDecoration.lineThrough,
                                ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          option.price,
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: option.onSale
                                    ? AppColors.error
                                    : AppColors.ink,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.tanFixed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            option.brand,
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: AppColors.espressoDark,
                                      fontWeight: FontWeight.w600,
                                    ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.matches,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.sage,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}
