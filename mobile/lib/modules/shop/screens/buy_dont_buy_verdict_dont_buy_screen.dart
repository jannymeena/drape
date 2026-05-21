import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

class BuyDontBuyVerdictDontBuyScreen extends StatelessWidget {
  static const path = 'buy-dont-buy/verdict-dont-buy';
  static const name = 'shop_buy_dont_buy_verdict_dont_buy';

  const BuyDontBuyVerdictDontBuyScreen({super.key});

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
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close,
                          color: AppColors.white, size: 40),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text('Skip this one',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppColors.error,
                            )),
                  ),
                  Center(
                    child: Text(r'Navy Blazer - $149.99',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  const SizedBox(height: 20),
                  _Card(
                    icon: Icons.warning_amber_rounded,
                    title: 'Only unlocks 2 new outfits',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('You already have similar items:',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (int i = 0; i < 2; i++) ...[
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: AppColors.ivoryWarm,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.checkroom_outlined,
                                    color: AppColors.taupeSoft),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.straighten,
                    title: 'May not fit well',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('This item runs small - size L recommended instead',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text('Or try Alternative Product',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.payments_outlined,
                    title: r'Overpriced at $149.99',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r'Similar items available for $80-$100',
                            style: Theme.of(context).textTheme.bodySmall),
                        const SizedBox(height: 6),
                        Text('View Better Options',
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _Card(
                    icon: Icons.autorenew,
                    title: 'Redundant purchase',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(
                          style: Theme.of(context).textTheme.bodySmall,
                          children: const [
                            TextSpan(text: 'You already have: '),
                            TextSpan(
                                text: 'Navy Blazer, Black Blazer',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        )),
                        const SizedBox(height: 4),
                        Text('Consider different color/style',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  fontStyle: FontStyle.italic,
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  DrapeButton(
                    label: 'View Alternatives',
                    onPressed: () => debugPrint('verdict: alternatives'),
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: AppColors.error),
                    ),
                    child: InkWell(
                      onTap: () => debugPrint('verdict: buy anyway'),
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 52,
                        child: Center(
                          child: Text('Ignore & Buy Anyway',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w700,
                                  )),
                        ),
                      ),
                    ),
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
            child: Text('Style Verdict',
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
        color: AppColors.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppColors.error,
                        )),
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
