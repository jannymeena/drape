import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/product_card.dart';
import '../widgets/product_options_sheet.dart';
import '../widgets/wishlist_toast.dart';

class GapAnalysisScreen extends StatefulWidget {
  static const path = 'gap-analysis';
  static const name = 'shop_gap_analysis';

  const GapAnalysisScreen({super.key});

  @override
  State<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends State<GapAnalysisScreen> {
  final _favorited = <String>{};
  int _filter = 0;
  static const _filters = ['All Recommendations', 'Tailored Fit', 'Sustainable'];

  final _products = const <ProductData>[
    ProductData(
      id: 'g1',
      brand: 'Loro Piana',
      name: 'Estate Cashmere Blazer',
      price: r'$2,450',
      unlockCount: 8,
      imageUrl: 'https://images.unsplash.com/photo-1507679799987-c73779587ccf?w=400',
    ),
    ProductData(
      id: 'g2',
      brand: 'Theory',
      name: 'Precision Ponte Blazer',
      price: r'$495',
      unlockCount: 8,
      imageUrl: 'https://images.unsplash.com/photo-1594938298603-c8148c4dae35?w=400',
    ),
    ProductData(
      id: 'g3',
      brand: 'The Row',
      name: 'Schoolboy Wool Blazer',
      price: r'$1,890',
      unlockCount: 8,
      imageUrl: 'https://images.unsplash.com/photo-1591047139829-d91aecb6caea?w=400',
    ),
    ProductData(
      id: 'g4',
      brand: 'Brunello Cucinelli',
      name: 'Deconstructed Navy Blazer',
      price: r'$3,150',
      unlockCount: 8,
      imageUrl: 'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?w=400',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _Header(onBack: () => context.pop())),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  Text('Fill Your Wardrobe Gap',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text('Elevate your personal atelier with intentional additions.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  _GapSummary(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _FilterPill(
                        label: _filters[i],
                        selected: i == _filter,
                        onTap: () => setState(() => _filter = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 20,
                  childAspectRatio: 0.56,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = _products[i];
                    return ProductCard(
                      product: p,
                      favorited: _favorited.contains(p.id),
                      showViewOptions: true,
                      onFavorite: () {
                        setState(() {
                          if (!_favorited.add(p.id)) _favorited.remove(p.id);
                        });
                        if (_favorited.contains(p.id)) showWishlistToast(context);
                      },
                      onViewOptions: () => showProductOptionsSheet(
                        context,
                        title: 'Navy Blazer',
                        unlockCount: 8,
                      ),
                    );
                  },
                  childCount: _products.length,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            child: Text('Gap Analysis',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.taupe,
                    )),
          ),
          Text('DRAPE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  )),
        ],
      ),
    );
  }
}

class _GapSummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppColors.white,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.adjust, color: AppColors.espresso, size: 22),
          ),
          const SizedBox(height: 12),
          Text('A navy blazer would unlock 8 new outfits',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            'Based on what you already own, adding a navy blazer creates 8 new outfit combinations.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (final label in ['WORK OUTFIT #1', 'EVENING MIX', 'CASUAL FRIDAY']) ...[
                Expanded(
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 1,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.checkroom_outlined,
                              color: AppColors.taupeSoft, size: 24),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                                fontWeight: FontWeight.w700,
                              )),
                    ],
                  ),
                ),
                if (label != 'CASUAL FRIDAY') const SizedBox(width: 8),
              ],
            ],
          ),
        ],
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
      color: selected ? AppColors.espresso : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
        ),
      ),
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
