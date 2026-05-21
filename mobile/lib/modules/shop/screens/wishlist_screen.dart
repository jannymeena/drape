import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'in_app_browser_screen.dart';

class WishlistScreen extends StatefulWidget {
  static const path = 'wishlist';
  static const name = 'shop_wishlist';

  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  final _items = <_WishItem>[
    const _WishItem(
        name: 'Cashmere Overcoat',
        brand: "Studio L'Artisan",
        price: r'$450',
        unlocks: 12),
    const _WishItem(
        name: 'Silk Pussy-Bow Blouse',
        brand: 'Maison Draper',
        price: r'$185',
        unlocks: 8),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('CURATED SELECTION',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.taupe,
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.w700,
                          )),
                  const SizedBox(height: 6),
                  Text(
                    'A collection of pieces that elevate your personal aesthetic. Each item is selected to harmonize with your existing wardrobe.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  if (_items.isEmpty)
                    _EmptyState()
                  else
                    for (int i = 0; i < _items.length; i++) ...[
                      _WishCard(
                        item: _items[i],
                        onOpen: () =>
                            context.goNamed(InAppBrowserScreen.name),
                        onRemove: () => setState(() => _items.removeAt(i)),
                      ),
                      const SizedBox(height: 16),
                    ],
                  const SizedBox(height: 16),
                  const Divider(color: AppColors.taupeSoft),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      '"Style is a way to say who you are without having to speak."',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                            color: AppColors.taupe,
                          ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('— RACHEL ZOE',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.taupe,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishItem {
  final String name;
  final String brand;
  final String price;
  final int unlocks;
  const _WishItem({
    required this.name,
    required this.brand,
    required this.price,
    required this.unlocks,
  });
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text('Wishlist',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const Icon(Icons.ios_share, color: AppColors.espresso),
        ],
      ),
    );
  }
}

class _WishCard extends StatelessWidget {
  final _WishItem item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;
  const _WishCard({
    required this.item,
    required this.onOpen,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.tanFixed,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.checkroom_outlined,
                    color: AppColors.espresso, size: 32),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name,
                        style: Theme.of(context).textTheme.titleMedium),
                    Text(item.brand,
                        style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Text(item.price,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.sageDim.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('UNLOCKS ${item.unlocks} OUTFITS',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: AppColors.sageContent,
                                    letterSpacing: 0.8,
                                    fontWeight: FontWeight.w700,
                                  )),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  GestureDetector(
                    onTap: onRemove,
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.taupe, size: 20),
                  ),
                  const SizedBox(height: 16),
                  const Icon(Icons.ios_share, color: AppColors.taupe, size: 18),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          const Icon(Icons.favorite_border, color: AppColors.taupe, size: 44),
          const SizedBox(height: 12),
          Text('Your wishlist is empty',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Tap the heart on any product to save it here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
