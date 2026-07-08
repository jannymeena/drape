import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/screens/compare_plans_screen.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/analytics_screen_view.dart';
import '../../../shared/models/api_error.dart';
import '../../wardrobe/image_pick.dart';
import '../models/shop.dart';
import '../shop_service.dart';
import '../widgets/buy_dont_buy_usage_banner.dart';
import '../widgets/measurement_required_modal.dart';
import 'buy_dont_buy_limit_reached_screen.dart';
import 'buy_dont_buy_verdict_buy_screen.dart';
import 'buy_dont_buy_verdict_dont_buy_screen.dart';

class BuyDontBuyScanScreen extends ConsumerStatefulWidget {
  static const path = 'buy-dont-buy';
  static const name = 'shop_buy_dont_buy';

  const BuyDontBuyScanScreen({super.key});

  @override
  ConsumerState<BuyDontBuyScanScreen> createState() =>
      _BuyDontBuyScanScreenState();
}

class _BuyDontBuyScanScreenState extends ConsumerState<BuyDontBuyScanScreen> {
  int _tab = 0; // 0 upload, 1 scan, 2 barcode
  bool _checking = false;

  static const _weeklyLimit = 5; // mirrors the backend free-tier cap

  int get _checksLeft {
    final history = ref.watch(buyCheckHistoryProvider).valueOrNull;
    if (history == null) return _weeklyLimit;
    final weekAgo = DateTime.now().subtract(const Duration(days: 7));
    final used = history.where((c) => c.createdAt.isAfter(weekAgo)).length;
    return (_weeklyLimit - used).clamp(0, _weeklyLimit);
  }

  /// Pick a photo -> `POST /shop/buy-check` -> verdict screen. One call per
  /// check; the 429 cap routes to the limit screen.
  Future<void> _startCheck() async {
    if (_checking) return;
    final image = await pickWardrobeImage(context);
    if (image == null || !mounted) return;
    setState(() => _checking = true);
    try {
      final verdict = await ref.read(shopServiceProvider).buyCheck(image);
      ref.invalidate(buyCheckHistoryProvider);
      if (!mounted) return;
      setState(() => _checking = false);
      context.goNamed(
        verdict.isBuy
            ? BuyDontBuyVerdictBuyScreen.name
            : BuyDontBuyVerdictDontBuyScreen.name,
        extra: verdict,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _checking = false);
      if (e.statusCode == 429) {
        ref
            .read(analyticsProvider)
            .capture(AnalyticsEvents.buyDontBuyLimitReached);
        context.goNamed(BuyDontBuyLimitReachedScreen.name);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _onTab(int i) async {
    setState(() => _tab = i);
    if (i == 1) {
      // Live camera scan reuses the same photo path for now.
      await _startCheck();
    } else if (i == 2) {
      ref.read(analyticsProvider).capture(
        AnalyticsEvents.measurementModalShown,
        {'source': 'buy_dont_buy'},
      );
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
                    AnalyticsScreenView(
                      event: AnalyticsEvents.buyDontBuyWarningShown,
                      properties: {'checks_left': _checksLeft},
                      child: BuyDontBuyUsageBanner(
                        checksLeft: _checksLeft,
                        onUpgrade: () =>
                            context.goNamed(BuyDontBuyLimitReachedScreen.name),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _checking
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.espresso),
                          ),
                        )
                      : _UploadCard(onPaste: _startCheck),
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
                  for (final check in ref
                          .watch(buyCheckHistoryProvider)
                          .valueOrNull ??
                      const <BuyDontBuyVerdict>[]) ...[
                    _RecentRow(
                      brand: check.isBuy ? 'BUY' : "DON'T BUY",
                      name: check.productName ?? 'Checked item',
                      note: 'Score ${check.score}/100',
                      buy: check.isBuy,
                      onTap: () => context.goNamed(
                        check.isBuy
                            ? BuyDontBuyVerdictBuyScreen.name
                            : BuyDontBuyVerdictDontBuyScreen.name,
                        extra: check,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  if ((ref.watch(buyCheckHistoryProvider).valueOrNull ??
                          const <BuyDontBuyVerdict>[])
                      .isEmpty)
                    Text('No checks yet — try your first one above.',
                        style: Theme.of(context).textTheme.bodyMedium),
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
