import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/measurement_incomplete_banner.dart';

class InAppBrowserScreen extends StatefulWidget {
  static const path = 'browser';
  static const name = 'shop_browser';

  const InAppBrowserScreen({super.key});

  @override
  State<InAppBrowserScreen> createState() => _InAppBrowserScreenState();
}

class _InAppBrowserScreenState extends State<InAppBrowserScreen> {
  int _size = 2; // M
  bool _fitComplete = false; // tap the banner to flip to "predicted to fit"
  static const _sizes = ['XS', 'S', 'M', 'L', 'XL'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _BrowserChrome(onClose: () => context.pop()),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  Container(
                    height: 280,
                    color: AppColors.ivoryWarm,
                    alignment: Alignment.center,
                    child: const Icon(Icons.checkroom,
                        color: AppColors.taupeSoft, size: 90),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_fitComplete)
                          _FitOkBanner()
                        else
                          MeasurementIncompleteBanner(
                            onTap: () => setState(() => _fitComplete = true),
                          ),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text('Navy Tailored Blazer',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge),
                                      const SizedBox(width: 8),
                                      if (_fitComplete)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.sageDim,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text('NEW',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .labelSmall
                                                  ?.copyWith(
                                                    color:
                                                        AppColors.sageContent,
                                                    fontWeight: FontWeight.w700,
                                                  )),
                                        ),
                                    ],
                                  ),
                                  Text('Ref: 2753132',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (_fitComplete)
                                  Text(r'$89.99',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: AppColors.taupe,
                                            decoration:
                                                TextDecoration.lineThrough,
                                          )),
                                Text(_fitComplete ? r'$79.00' : r'$89.99',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: _fitComplete
                                              ? AppColors.sage
                                              : AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                        )),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('SELECT SIZE',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.taupe,
                                      letterSpacing: 1.4,
                                      fontWeight: FontWeight.w700,
                                    )),
                            Text('SIZE GUIDE',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      color: AppColors.espresso,
                                      letterSpacing: 1.0,
                                      fontWeight: FontWeight.w700,
                                      decoration: TextDecoration.underline,
                                    )),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(_sizes.length, (i) {
                            final sel = i == _size;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () => setState(() => _size = i),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? AppColors.espresso
                                        : AppColors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sel
                                          ? AppColors.espresso
                                          : AppColors.taupeSoft,
                                    ),
                                  ),
                                  child: Text(_sizes[i],
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                            color: sel
                                                ? AppColors.white
                                                : AppColors.ink,
                                          )),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: AppColors.espresso,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: null, // retailer cart integration is post-v1
                              borderRadius: BorderRadius.circular(12),
                              child: const SizedBox(
                                height: 52,
                                child: Center(
                                  child: Text('ADD TO CART',
                                      style: TextStyle(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.4,
                                      )),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Straight-cut blazer with a lapel collar and long sleeves. Featuring front flap pockets, a chest welt pocket, and a back vent at the hem. Tonal interior lining, front button fastening.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        for (final f in const [
                          '100% Wool-Cuoio',
                          'Signature Tailored Fit',
                          'Dry Clean Only',
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.circle,
                                    color: AppColors.taupe, size: 5),
                                const SizedBox(width: 8),
                                Text(f,
                                    style:
                                        Theme.of(context).textTheme.bodySmall),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _Footer(),
          ],
        ),
      ),
    );
  }
}

class _BrowserChrome extends StatelessWidget {
  final VoidCallback onClose;
  const _BrowserChrome({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.espressoDeep,
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.brandText, size: 20),
            onPressed: onClose,
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.lock_outline,
                      color: AppColors.tan, size: 12),
                  const SizedBox(width: 6),
                  Text('DRAPE · jcrew.com',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: AppColors.brandText,
                          )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FitOkBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppColors.sage, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Predicted to fit well based on your measurements',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.sageContent,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.taupeSoft)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, color: AppColors.gold, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Unlocks 8 outfits in DRAPE',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.sage,
                        fontWeight: FontWeight.w600,
                      )),
            ),
            Text('2 checks left',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.taupe,
                      fontWeight: FontWeight.w700,
                    )),
          ],
        ),
      ),
    );
  }
}
