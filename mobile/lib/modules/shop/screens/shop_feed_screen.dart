import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/edit_measurements_screen.dart';
import '../models/shop.dart';
import '../shop_service.dart';
import '../widgets/measurement_incomplete_banner.dart';
import '../widgets/product_card.dart';
import '../widgets/product_options_sheet.dart';
import '../widgets/wishlist_toast.dart';
import 'ai_advisor_initial_screen.dart';
import 'buy_dont_buy_scan_screen.dart';
import 'gap_analysis_screen.dart';
import 'wishlist_screen.dart';

class ShopFeedScreen extends ConsumerStatefulWidget {
  static const path = '/shop';
  static const name = 'shop_feed';

  const ShopFeedScreen({super.key});

  @override
  ConsumerState<ShopFeedScreen> createState() => _ShopFeedScreenState();
}

class _ShopFeedScreenState extends ConsumerState<ShopFeedScreen> {
  int _category = 0;
  static const _categories = ['Tamil wedding outfit', 'Beach vacation', 'Office'];

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

  static ProductData _toCard(ShopProduct p) => ProductData(
        id: p.id,
        brand: p.brand,
        name: p.name,
        price: p.priceLabel,
        imageUrl: p.imageUrl.isEmpty ? null : p.imageUrl,
      );

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(shopFeedProvider);
    final products = feed.valueOrNull?.products ?? const <ShopProduct>[];
    final measurementsComplete =
        feed.valueOrNull?.measurementsComplete ?? true;
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TopBar()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate.fixed([
                  _AiSearchBar(onTap: () => context.goNamed(AiAdvisorInitialScreen.name)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _CategoryPill(
                        label: _categories[i],
                        selected: i == _category,
                        onTap: () => setState(() => _category = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (!measurementsComplete) ...[
                    MeasurementIncompleteBanner(
                      onTap: () =>
                          context.goNamed(EditMeasurementsScreen.name),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _GapFoundCard(
                    onView: () => context.goNamed(GapAnalysisScreen.name),
                  ),
                  const SizedBox(height: 14),
                  _BuyDontBuyCard(
                      onTap: () => context.goNamed(BuyDontBuyScanScreen.name)),
                  const SizedBox(height: 20),
                  Text("Curated Essentials",
                      style: Theme.of(context).textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  if (feed.isLoading && products.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.espresso),
                      ),
                    )
                  else if (feed.hasError && products.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton(
                          onPressed: () => ref.invalidate(shopFeedProvider),
                          child: const Text("Couldn't load products — retry"),
                        ),
                      ),
                    ),
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
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final p = products[i];
                    return ProductCard(
                      product: _toCard(p),
                      favorited: _wishlisted.contains(p.id),
                      onFavorite: () => _toggleWishlist(p),
                      onTap: () => showProductOptionsSheet(
                        context,
                        title: p.name,
                        unlockCount: 6,
                      ),
                    );
                  },
                  childCount: products.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
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

class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 16, 0),
      child: Row(
        children: [
          Text('Shop',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  )),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.favorite_border, color: AppColors.espresso),
            onPressed: () => context.goNamed(WishlistScreen.name),
          ),
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('PRO',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.white,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const SizedBox(width: 10),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.espresso,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('AC',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.white,
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ],
      ),
    );
  }
}

class _AiSearchBar extends StatelessWidget {
  final VoidCallback onTap;
  const _AiSearchBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.gold, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Ask your AI stylist anything...',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ),
            const Icon(Icons.send, color: AppColors.espresso, size: 18),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill({
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

class _GapFoundCard extends StatelessWidget {
  final VoidCallback onView;
  const _GapFoundCard({required this.onView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.gold, size: 14),
              const SizedBox(width: 6),
              Text(
                'YOUR STYLIST FOUND A GAP',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.gold,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'A navy blazer would unlock 8 new outfits from what you already own.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.brandText,
                ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.checkroom_outlined,
                      color: AppColors.tan, size: 22),
                ),
                const SizedBox(width: 8),
              ],
              const Spacer(),
              Material(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View Options',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.espressoDark,
                                  fontWeight: FontWeight.w700,
                                )),
                        const SizedBox(width: 4),
                        const Icon(Icons.arrow_forward,
                            color: AppColors.espressoDark, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuyDontBuyCard extends StatelessWidget {
  final VoidCallback onTap;
  const _BuyDontBuyCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryWarm,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.camera_alt_outlined,
                    color: AppColors.espresso, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Buy/Don\'t-Buy Checker',
                            style: Theme.of(context).textTheme.titleSmall),
                        const Spacer(),
                        Text('3 left today',
                            style: Theme.of(context).textTheme.bodySmall),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Scan any item before you buy. ZOURA tells you if it fits your wardrobe.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
