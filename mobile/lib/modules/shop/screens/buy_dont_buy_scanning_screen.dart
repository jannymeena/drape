import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'buy_dont_buy_confirm_product_screen.dart';

class BuyDontBuyScanningScreen extends StatelessWidget {
  static const path = 'buy-dont-buy/scan';
  static const name = 'shop_buy_dont_buy_scanning';

  const BuyDontBuyScanningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _Viewfinder()),
            Positioned(
              top: 8,
              left: 4,
              child: _CircleButton(
                icon: Icons.close,
                onTap: () => context.pop(),
              ),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text('SCAN ITEM TO ANALYZE',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.brandText,
                          letterSpacing: 2,
                          fontWeight: FontWeight.w700,
                        )),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sageDim.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle,
                              color: AppColors.sage, size: 16),
                          const SizedBox(width: 8),
                          Text('Detected: Navy Tailored Blazer',
                              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.sageContent,
                                    fontWeight: FontWeight.w600,
                                  )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: AppColors.espresso,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: () =>
                              context.goNamed(ConfirmProductScreen.name),
                          borderRadius: BorderRadius.circular(14),
                          child: const SizedBox(
                            height: 56,
                            child: Center(
                              child: Text('ANALYZE THIS ITEM',
                                  style: TextStyle(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.6,
                                  )),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A130C), Color(0xFF3B2A1F), Color(0xFF1A130C)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.gold, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.checkroom_outlined,
                  color: AppColors.tan, size: 64),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.brandText, size: 20),
      ),
    );
  }
}
