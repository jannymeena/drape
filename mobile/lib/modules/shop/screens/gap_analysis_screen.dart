import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/compare_plans_screen.dart';
import '../models/shop.dart';
import '../shop_service.dart';
import '../widgets/product_card.dart';
import '../widgets/product_options_sheet.dart';
import '../widgets/wishlist_toast.dart';

class GapAnalysisScreen extends ConsumerStatefulWidget {
  static const path = 'gap-analysis';
  static const name = 'shop_gap_analysis';

  const GapAnalysisScreen({super.key});

  @override
  ConsumerState<GapAnalysisScreen> createState() => _GapAnalysisScreenState();
}

class _GapAnalysisScreenState extends ConsumerState<GapAnalysisScreen> {
  int _filter = 0;
  static const _filters = ['All Recommendations', 'Tailored Fit', 'Sustainable'];

  Set<String> get _wishlisted => {
        for (final e in ref.watch(wishlistProvider).valueOrNull ??
            const <WishlistEntry>[])
          e.product.id,
      };

  Future<void> _toggleWishlist(ShopProduct product) async {
    final service = ref.read(shopServiceProvider);
    final adding = !_wishlisted.contains(product.id);
    try {
      if (adding) {
        await service.addToWishlist(product.id);
      } else {
        await service.removeFromWishlist(product.id);
      }
      ref.invalidate(wishlistProvider);
      if (mounted) showWishlistToast(context, added: adding);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final gaps = ref.watch(gapAnalysisProvider).valueOrNull;
    final topGap = (gaps?.gaps.isNotEmpty ?? false) ? gaps!.gaps.first : null;
    // Recommend real catalog products for the biggest gap's category.
    final feedProducts =
        ref.watch(shopFeedProvider).valueOrNull?.products ??
            const <ShopProduct>[];
    final products = topGap == null
        ? feedProducts
        : feedProducts.where((p) => p.category == topGap.category).toList();
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
                  _GapSummary(gap: topGap),
                  if (gaps?.isTeaser ?? false) ...[
                    const SizedBox(height: 12),
                    _ProTeaserCard(
                      message: gaps!.proTeaser ??
                          'Upgrade to Zoura Pro for the full analysis.',
                      onUpgrade: () =>
                          context.goNamed(ComparePlansScreen.name),
                    ),
                  ],
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
                    final p = products[i];
                    return ProductCard(
                      product: ProductData(
                        id: p.id,
                        brand: p.brand,
                        name: p.name,
                        price: p.priceLabel,
                        imageUrl: p.imageUrl.isEmpty ? null : p.imageUrl,
                        unlockCount: topGap?.outfitsUnlocked,
                      ),
                      favorited: _wishlisted.contains(p.id),
                      showViewOptions: true,
                      onFavorite: () => _toggleWishlist(p),
                      onViewOptions: () => showProductOptionsSheet(
                        context,
                        title: p.name,
                        unlockCount: topGap?.outfitsUnlocked ?? 0,
                      ),
                    );
                  },
                  childCount: products.length,
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
          Text('ZOURA',
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
  final GapItem? gap;
  const _GapSummary({required this.gap});

  @override
  Widget build(BuildContext context) {
    final headline = gap == null
        ? 'Your wardrobe has no major gaps'
        : 'Adding ${gap!.category} would unlock ${gap!.outfitsUnlocked} new outfits';
    final body = gap?.reason ??
        'Nice work — every core category is covered. Browse the feed for upgrades.';
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
          Text(headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            body,
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

class _ProTeaserCard extends StatelessWidget {
  final String message;
  final VoidCallback onUpgrade;
  const _ProTeaserCard({required this.message, required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.gold.withValues(alpha: 0.25),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onUpgrade,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.lock_outline,
                  color: AppColors.goldDark, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: Theme.of(context).textTheme.bodyMedium),
              ),
              const Icon(Icons.chevron_right, color: AppColors.goldDark),
            ],
          ),
        ),
      ),
    );
  }
}
