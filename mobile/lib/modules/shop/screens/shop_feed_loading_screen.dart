import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';

/// Loading state — no mockup; built with the shared ShimmerSkeleton so the feed
/// has a graceful placeholder while products fetch in Phase E.
class ShopFeedLoadingScreen extends StatelessWidget {
  static const path = 'loading';
  static const name = 'shop_feed_loading';

  const ShopFeedLoadingScreen({super.key});

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
                  const ShimmerSkeleton(
                    height: 52,
                    borderRadius: BorderRadius.all(Radius.circular(999)),
                  ),
                  const SizedBox(height: 16),
                  const ShimmerSkeleton(
                    height: 120,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  const SizedBox(height: 20),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 20,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 0.62,
                    children: List.generate(
                      4,
                      (_) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          AspectRatio(
                            aspectRatio: 1,
                            child: ShimmerSkeleton(
                              borderRadius: BorderRadius.all(Radius.circular(12)),
                            ),
                          ),
                          SizedBox(height: 8),
                          ShimmerSkeleton(width: 80, height: 10),
                          SizedBox(height: 6),
                          ShimmerSkeleton(width: 120, height: 12),
                          SizedBox(height: 6),
                          ShimmerSkeleton(width: 50, height: 12),
                        ],
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
