import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/add_to_wardrobe_chooser.dart';
import '../widgets/capacity_warning_banner.dart';
import '../widgets/category_filter_chips.dart';
import '../widgets/item_card.dart';
import 'batch_upload_screen.dart';
import 'item_detail_screen.dart';
import 'manual_entry_screen.dart' as wardrobe_manual;
import 'scanner_screen.dart';

class WardrobeScreen extends StatefulWidget {
  static const path = '/wardrobe';
  static const name = 'wardrobe';

  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  static const _categories = [
    'All Pieces',
    'Tops',
    'Bottoms',
    'Outerwear',
    'Shoes',
    'Knitwear',
  ];
  int _categoryIndex = 0;
  final _items = const <WardrobeItemData>[
    WardrobeItemData(
      id: 'i1',
      name: 'Cashmere Blend Trench',
      category: 'Outerwear',
      imageUrl:
          'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
      starter: true,
    ),
    WardrobeItemData(
      id: 'i2',
      name: 'Ivory Satin Shirt',
      category: 'Tops',
      imageUrl:
          'https://images.unsplash.com/photo-1602810318383-e386cc2a3ccf?w=400',
    ),
    WardrobeItemData(
      id: 'i3',
      name: 'Raw Indigo Denim',
      category: 'Bottoms',
      imageUrl:
          'https://images.unsplash.com/photo-1542272604-787c3835535d?w=400',
    ),
    WardrobeItemData(
      id: 'i4',
      name: 'Oatmeal Cable Knit',
      category: 'Knitwear',
      imageUrl:
          'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
      favorited: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(onAdd: _openAddSheet),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Text(
                      'Wardrobe',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _SearchField(),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: CapacityWarningBanner(
                      used: 24,
                      total: 30,
                      level: CapacityLevel.soft,
                      onUpgrade: () => debugPrint('wardrobe: upgrade'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  CategoryFilterChips(
                    categories: _categories,
                    selectedIndex: _categoryIndex,
                    onSelected: (i) => setState(() => _categoryIndex = i),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _items.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 20,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (_, i) => ItemCard(
                        item: _items[i],
                        onTap: () => context.goNamed(
                          ItemDetailScreen.name,
                          pathParameters: {'id': _items[i].id},
                        ),
                        onFavorite: () => debugPrint('fav ${_items[i].id}'),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _GrowYourWardrobeCard(onAdd: _openAddSheet),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAddSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.ivory,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => Column(
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
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: AddToWardrobeChooser(
                    used: 24,
                    remaining: 6,
                    onUpgrade: () => debugPrint('add: upgrade'),
                    onChoice: (choice) {
                      Navigator.of(ctx).pop();
                      switch (choice) {
                        case AddToWardrobeChoice.upload:
                          context.goNamed(BatchUploadScreen.name);
                        case AddToWardrobeChoice.scan:
                          context.goNamed(ScannerScreen.name);
                        case AddToWardrobeChoice.manual:
                          context.goNamed(
                            wardrobe_manual.ManualEntryScreen.name,
                          );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onAdd;
  const _TopBar({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: Row(
        children: [
          Text(
            'DRAPE',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.espresso,
                  letterSpacing: 4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.espresso),
            onPressed: () => debugPrint('wardrobe: search'),
          ),
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.espresso),
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.taupe, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search your pieces...',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowYourWardrobeCard extends StatelessWidget {
  final VoidCallback onAdd;
  const _GrowYourWardrobeCard({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.taupeSoft),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.ivoryDim,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.add, color: AppColors.espresso),
          ),
          const SizedBox(height: 12),
          Text(
            'Grow Your Wardrobe',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Digitize your favorite pieces to unlock personalized styling recommendations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.espresso,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onAdd,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Text(
                  'Add New Item',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
