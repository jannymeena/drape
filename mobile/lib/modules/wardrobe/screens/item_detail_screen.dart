import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/remove_confirmation_modal.dart';

class ItemDetailScreen extends StatelessWidget {
  static const path = 'items/:id';
  static const name = 'wardrobe_item_detail';

  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  static const _appearances = <_AppearanceMock>[
    _AppearanceMock(),
    _AppearanceMock(),
    _AppearanceMock(),
  ];

  static const _attributes = <_Attribute>[
    _Attribute(label: 'Added', value: 'March 2024'),
    _Attribute(label: 'Color', value: 'White'),
    _Attribute(label: 'Material', value: 'Cotton'),
    _Attribute(label: 'Season', value: 'All'),
    _Attribute(label: 'Last worn', value: '2 days ago'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(
              onBack: () => context.pop(),
              onMore: () => debugPrint('item: more'),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
                children: [
                  _HeroImage(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'White Oxford Shirt',
                          style:
                              Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Brand · Added March 2024',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        _CostPerWearCard(),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Appeared in 8 outfits',
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  debugPrint('item: view all outfits'),
                              child: Text(
                                'View All',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.espresso,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _appearances.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(width: 12),
                            itemBuilder: (_, _) => const _AppearanceTile(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.taupeSoft),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0; i < _attributes.length; i++)
                                _AttributeRow(
                                  attribute: _attributes[i],
                                  showDivider: i < _attributes.length - 1,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _BottomActions(itemId: itemId),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onMore;
  const _TopBar({required this.onBack, required this.onMore});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.espresso),
            onPressed: onMore,
          ),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: AppColors.tanFixed,
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.checkroom_outlined,
                    color: AppColors.espresso,
                    size: 96,
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'TOP',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.white,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child:
                      const Icon(Icons.edit, color: AppColors.espresso, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostPerWearCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'COST PER WEAR',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brandText.withValues(alpha: 0.7),
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageDim,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.trending_up,
                        color: AppColors.sage, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      'IMPROVING',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.sageContent,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r'$3.20',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.brandText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            r'$3.20 per wear (22 wears, $70.40 purchase price)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _Attribute {
  final String label;
  final String value;
  const _Attribute({required this.label, required this.value});
}

class _AttributeRow extends StatelessWidget {
  final _Attribute attribute;
  final bool showDivider;

  const _AttributeRow({
    required this.attribute,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? BorderSide(color: AppColors.taupeSoft.withValues(alpha: 0.6))
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              attribute.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.taupe,
                  ),
            ),
          ),
          Text(
            attribute.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceMock {
  const _AppearanceMock();
}

class _AppearanceTile extends StatelessWidget {
  const _AppearanceTile();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        color: AppColors.ivoryWarm,
        alignment: Alignment.center,
        child: const Icon(
          Icons.checkroom_outlined,
          color: AppColors.taupeSoft,
          size: 32,
        ),
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final String itemId;
  const _BottomActions({required this.itemId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          children: [
            Material(
              color: AppColors.espresso,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: () => debugPrint('item: log as worn today'),
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'Log as Worn Today',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              child: InkWell(
                onTap: () async {
                  final confirmed = await RemoveConfirmationModal.show(
                    context,
                    itemName: 'White Oxford Shirt',
                  );
                  if (confirmed && context.mounted) {
                    debugPrint('item $itemId removed');
                    context.pop();
                  }
                },
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'Remove from Wardrobe',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
