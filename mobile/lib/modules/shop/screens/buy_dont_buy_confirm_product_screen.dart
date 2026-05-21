import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import 'buy_dont_buy_choose_image_screen.dart';
import 'buy_dont_buy_verdict_buy_screen.dart';

class ConfirmProductScreen extends StatelessWidget {
  static const path = 'buy-dont-buy/confirm';
  static const name = 'shop_buy_dont_buy_confirm';

  const ConfirmProductScreen({super.key});

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
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16)),
                          child: Container(
                            height: 280,
                            width: double.infinity,
                            color: AppColors.ivoryWarm,
                            alignment: Alignment.center,
                            child: const Icon(Icons.checkroom,
                                color: AppColors.taupeSoft, size: 90),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text('Navy Tailored Blazer',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.tanFixed,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text('Color: Navy',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelMedium
                                            ?.copyWith(
                                              color: AppColors.espressoDark,
                                              fontWeight: FontWeight.w600,
                                            )),
                                  ),
                                ],
                              ),
                              Text('J.Crew',
                                  style: Theme.of(context).textTheme.bodyMedium),
                              const SizedBox(height: 8),
                              Text(r'$89.99',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text('Is this the item you want to check?',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontStyle: FontStyle.italic,
                            )),
                  ),
                  const SizedBox(height: 16),
                  DrapeButton(
                    label: 'Yes, Analyze This Item',
                    onPressed: () =>
                        context.goNamed(BuyDontBuyVerdictBuyScreen.name),
                  ),
                  const SizedBox(height: 10),
                  DrapeButton.outlined(
                    label: 'No, Choose Different Image',
                    onPressed: () =>
                        context.goNamed(ChooseProductImageScreen.name),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Color(0xFFC8901C), size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This will use 1 of your 2 remaining checks',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF7D5A11),
                                ),
                          ),
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
            child: Text('CONFIRM PRODUCT',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.tanFixed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: AppColors.espresso, size: 16),
          ),
        ],
      ),
    );
  }
}
