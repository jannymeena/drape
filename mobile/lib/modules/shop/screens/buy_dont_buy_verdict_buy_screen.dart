import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/shop.dart';
import '../../../shared/widgets/drape_button.dart';
import 'in_app_browser_screen.dart';

class BuyDontBuyVerdictBuyScreen extends StatelessWidget {
  static const path = 'buy-dont-buy/verdict-buy';
  static const name = 'shop_buy_dont_buy_verdict_buy';

  /// Real verdict from `POST /shop/buy-check` (router `extra`); null keeps
  /// the illustrative mockup copy (e.g. deep links without state).
  final BuyDontBuyVerdict? verdict;

  const BuyDontBuyVerdictBuyScreen({super.key, this.verdict});

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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.sage,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.check,
                          color: AppColors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('Worth buying',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ),
                  Center(
                    child: Text(
                        verdict == null
                            ? r'Navy Blazer — $89.99'
                            : '${verdict!.productName ?? 'Your item'} — score ${verdict!.score}/100',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    icon: Icons.auto_awesome,
                    title: 'Unlocks 8 new outfits',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: 4,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, _) => Container(
                              width: 72,
                              decoration: BoxDecoration(
                                color: AppColors.ivoryWarm,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.center,
                              child: const Icon(Icons.checkroom_outlined,
                                  color: AppColors.taupeSoft),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text.rich(TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: const [
                            TextSpan(
                                text: 'Pairs with: ',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextSpan(
                                text:
                                    'White Shirt, Black Trousers, Brown Shoes, Cream Knitwear'),
                          ],
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.straighten,
                    title: 'Predicted to fit you well ✓',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            verdict?.fitReason.isNotEmpty == true
                                ? verdict!.fitReason
                                : 'Based on your measurements (chest 40", waist 32")',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 4),
                        Text('Size M recommended',
                            style: Theme.of(context).textTheme.titleSmall),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.payments_outlined,
                    title: r'Good value at $89.99',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            verdict?.valueReason.isNotEmpty == true
                                ? verdict!.valueReason
                                : r'Average cost per wear: $7.50 / worn ~12x yr',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: const LinearProgressIndicator(
                            value: 0.7,
                            minHeight: 8,
                            backgroundColor: AppColors.sand,
                            valueColor:
                                AlwaysStoppedAnimation(AppColors.sage),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(r'Similar premium items typically range: $70–$120',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.track_changes,
                    title: 'Fills a gap in your wardrobe',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.ivoryWarm,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                              verdict?.gapReason.isNotEmpty == true
                                  ? verdict!.gapReason
                                  : "You don't have a navy blazer yet",
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        const SizedBox(height: 10),
                        Text('COMPLETES 3 CATEGORIES',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppColors.taupe,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w700,
                                )),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: const [
                            _CatChip('Work'),
                            _CatChip('Smart Casual'),
                            _CatChip('Date Night'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DrapeButton(
                    label: 'View Product Details',
                    onPressed: () => context.goNamed(InAppBrowserScreen.name),
                    leading: const Icon(Icons.open_in_new,
                        color: AppColors.white, size: 16),
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
            child: Text('The Verdict',
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

class _Card extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const _Card({required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _CatChip extends StatelessWidget {
  final String label;
  const _CatChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.sand,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
