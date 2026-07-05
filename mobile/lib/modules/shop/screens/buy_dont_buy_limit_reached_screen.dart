import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../profile/screens/compare_plans_screen.dart';
import '../../../shared/theme/app_colors.dart';

class BuyDontBuyLimitReachedScreen extends StatelessWidget {
  static const path = 'buy-dont-buy/limit-reached';
  static const name = 'shop_buy_dont_buy_limit';

  const BuyDontBuyLimitReachedScreen({super.key});

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
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
                children: [
                  Center(
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: AppColors.errorContainer,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.block, color: AppColors.error, size: 44),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Weekly Limit Reached',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineLarge),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "You've used all 5 Buy/Don't Buy checks this week. Your limit resets Monday at 5 AM.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.ivoryWarm,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        Text('RESETS IN',
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                  color: AppColors.taupe,
                                  letterSpacing: 1.4,
                                  fontWeight: FontWeight.w700,
                                )),
                        const SizedBox(height: 6),
                        Text('3d 14h 32m',
                            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w800,
                                )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('In the meantime:',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 12),
                        const _Bullet('Browse gap analysis recommendations'),
                        const SizedBox(height: 10),
                        const _Bullet('Add items to wishlist'),
                        const SizedBox(height: 10),
                        const _Bullet('Shop with AI Style Advisor'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => context.goNamed(ComparePlansScreen.name),
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 56,
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Upgrade to Pro',
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(
                                        color: AppColors.espressoDark,
                                        fontWeight: FontWeight.w700,
                                      )),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward,
                                  color: AppColors.espressoDark, size: 18),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Text('Unlimited checks + priority fit predictions',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  Center(
                    child: Text(r'Starting at $14.99/month',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.taupe,
                            )),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () => debugPrint('limit: purchase history'),
                      child: Text('View Purchase History',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: AppColors.espresso,
                                fontWeight: FontWeight.w700,
                                decoration: TextDecoration.underline,
                              )),
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
            child: Text('Digital Atelier',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String label;
  const _Bullet(this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.check_circle, color: AppColors.sage, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    );
  }
}
