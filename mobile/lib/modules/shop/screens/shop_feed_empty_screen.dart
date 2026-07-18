import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../profile/screens/edit_measurements_screen.dart';
import '../../../shared/widgets/drape_button.dart';

/// Empty state — no mockup; designed consistent with the module. Shown when the
/// user's style profile is incomplete so the feed can't curate yet.
class ShopFeedEmptyScreen extends StatelessWidget {
  static const path = 'empty';
  static const name = 'shop_feed_empty';

  const ShopFeedEmptyScreen({super.key});

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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: AppColors.ivoryWarm,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.storefront_outlined,
                          color: AppColors.taupe, size: 40),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Your shop is waiting',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Complete your style profile so ZOURA can curate products and spot wardrobe gaps tailored to you.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    DrapeButton(
                      label: 'Complete Style Profile',
                      onPressed: () =>
                          context.goNamed(EditMeasurementsScreen.name),
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text('Shop',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ],
      ),
    );
  }
}
