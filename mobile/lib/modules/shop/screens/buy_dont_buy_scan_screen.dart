import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../profile/screens/compare_plans_screen.dart';
import '../../../shared/theme/app_colors.dart';
import '../widgets/buy_dont_buy_usage_banner.dart';
import '../widgets/measurement_required_modal.dart';
import 'buy_dont_buy_confirm_product_screen.dart';
import 'buy_dont_buy_limit_reached_screen.dart';
import 'buy_dont_buy_scanning_screen.dart';
import 'buy_dont_buy_verdict_buy_screen.dart';
import 'buy_dont_buy_verdict_dont_buy_screen.dart';

class BuyDontBuyScanScreen extends StatefulWidget {
  static const path = 'buy-dont-buy';
  static const name = 'shop_buy_dont_buy';

  const BuyDontBuyScanScreen({super.key});

  @override
  State<BuyDontBuyScanScreen> createState() => _BuyDontBuyScanScreenState();
}

class _BuyDontBuyScanScreenState extends State<BuyDontBuyScanScreen> {
  int _tab = 0; // 0 upload, 1 scan, 2 barcode
  int _checksLeft = 1; // near the weekly limit → warning banner shows

  static const _recent = [
    ('Theory', 'Oakland Wool Overcoat', 'Unlocks 6 outfits', true),
    ('Levi\'s Made & Crafted', 'Raw Indigo Straight Leg', 'Unlocks 4 outfits', true),
    ('Zara', 'Abstract Print Satin Shirt', 'Only 1 match', false),
  ];

  void _startCheck() {
    if (_checksLeft <= 0) {
      context.goNamed(BuyDontBuyLimitReachedScreen.name);
      return;
    }
    setState(() => _checksLeft--);
    context.goNamed(ConfirmProductScreen.name);
  }

  Future<void> _onTab(int i) async {
    setState(() => _tab = i);
    if (i == 1) {
      context.goNamed(BuyDontBuyScanningScreen.name);
    } else if (i == 2) {
      await showMeasurementRequiredModal(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(checksLeft: _checksLeft, onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  Text('Check before you buy.',
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'See how many outfits a new item unlocks before spending.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 16),
                  _MethodTabs(selected: _tab, onSelected: _onTab),
                  if (_checksLeft <= 1) ...[
                    const SizedBox(height: 12),
                    BuyDontBuyUsageBanner(
                      checksLeft: _checksLeft,
                      onUpgrade: () =>
                          context.goNamed(BuyDontBuyLimitReachedScreen.name),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _UploadCard(onPaste: _startCheck),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: Text('Recent Checks',
                            style: Theme.of(context).textTheme.titleLarge),
                      ),
                      Text('VIEW ALL',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.espresso,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final r in _recent) ...[
                    _RecentRow(
                      brand: r.$1,
                      name: r.$2,
                      note: r.$3,
                      buy: r.$4,
                      onTap: () => context.goNamed(
                        r.$4
                            ? BuyDontBuyVerdictBuyScreen.name
                            : BuyDontBuyVerdictDontBuyScreen.name,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 12),
                  _ProUpsell(),
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
  final int checksLeft;
  final VoidCallback onBack;
  const _Header({required this.checksLeft, required this.onBack});

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
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w700,
                    )),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text('$checksLeft LEFT TODAY',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.espressoDark,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    )),
          ),
        ],
      ),
    );
  }
}

class _MethodTabs extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _MethodTabs({required this.selected, required this.onSelected});

  static const _tabs = [
    ('UPLOAD', Icons.upload_file_outlined),
    ('SCAN ITEM', Icons.camera_alt_outlined),
    ('BARCODE', Icons.qr_code_scanner),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final sel = i == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelected(i),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.espresso : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(_tabs[i].$2,
                        color: sel ? AppColors.white : AppColors.inkSoft,
                        size: 18),
                    const SizedBox(height: 4),
                    Text(_tabs[i].$1,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: sel ? AppColors.white : AppColors.inkSoft,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                            )),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  final VoidCallback onPaste;
  const _UploadCard({required this.onPaste});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.link, color: AppColors.brandText, size: 20),
          ),
          const SizedBox(height: 12),
          Text('Analyze item from web link',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.brandText,
                    fontStyle: FontStyle.italic,
                  )),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text('Paste product URL here...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.brandText.withValues(alpha: 0.5),
                          )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: onPaste,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.content_paste,
                          color: AppColors.espresso, size: 16),
                      const SizedBox(width: 8),
                      Text('PASTE PRODUCT LINK',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppColors.espresso,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              )),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  final String brand;
  final String name;
  final String note;
  final bool buy;
  final VoidCallback onTap;
  const _RecentRow({
    required this.brand,
    required this.name,
    required this.note,
    required this.buy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.ivoryWarm,
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.checkroom_outlined,
                    color: AppColors.taupeSoft),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(brand.toUpperCase(),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.taupe,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                            )),
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(note, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: buy ? AppColors.sage : AppColors.errorContainer,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(buy ? 'BUY' : 'SKIP',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: buy ? AppColors.white : AppColors.error,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w700,
                            )),
                    const SizedBox(width: 3),
                    Icon(buy ? Icons.check : Icons.close,
                        color: buy ? AppColors.white : AppColors.error, size: 11),
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

class _ProUpsell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.espresso, AppColors.espressoDark],
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium, color: AppColors.gold, size: 16),
              const SizedBox(width: 6),
              Text('DRAPE ATELIER PRO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.gold,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      )),
            ],
          ),
          const SizedBox(height: 8),
          Text('Unlimited checks for serious shoppers.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.brandText,
                  )),
          const SizedBox(height: 4),
          Text(
            'Stop guessing. Get infinite AI styling advice and wardrobe mapping today.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: Material(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => context.goNamed(ComparePlansScreen.name),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('UPGRADE TO UNLIMITED',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.espressoDark,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            )),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
