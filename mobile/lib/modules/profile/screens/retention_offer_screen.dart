import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../billing_service.dart';
import 'contact_us_screen.dart';
import 'final_cancellation_confirmation_screen.dart';

class RetentionOfferScreen extends ConsumerWidget {
  static const path = 'retention-offer';
  static const name = 'profile_retention_offer';

  const RetentionOfferScreen({super.key});

  Future<void> _accept(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(billingServiceProvider).acceptRetentionOffer();
      ref.read(analyticsProvider).capture(
        AnalyticsEvents.subscriptionReactivated,
        {'source': 'retention_offer'},
      );
      ref.invalidate(subscriptionProvider);
      ref.invalidate(billingHistoryProvider);
      if (!context.mounted) return;
      showDrapeToast(context, "Offer applied — you're staying on Pro!");
      context.pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onClose: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                children: [
                  Center(
                    child: Text(
                      'Before you go…',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We'd love to keep styling you. Here is a special invitation to continue your journey at The Atelier.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 24),
                  _OfferCard(),
                  const SizedBox(height: 24),
                  Material(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _accept(context, ref),
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Center(
                          child: Text(
                            _offerLabel(ref),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: AppColors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.4,
                                ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: TextButton(
                      onPressed: () => context
                          .goNamed(FinalCancellationConfirmationScreen.name),
                      child: Text(
                        'NO THANKS, CANCEL ANYWAY',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppColors.inkSoft,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                  ),
                  const Divider(height: 32, color: AppColors.taupeSoft),
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
  final VoidCallback onClose;
  const _Header({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.ink),
            onPressed: onClose,
          ),
          Expanded(
            child: Text(
              'THE ATELIER',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline, color: AppColors.ink),
            onPressed: () => context.goNamed(ContactUsScreen.name),
          ),
        ],
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.gold,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'SPECIAL OFFER',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.white,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Get 50% off your next 3 months',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(
            r'Just $7.50/month',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 18),
          _Bullet(label: 'Personalized AI Lookbooks weekly'),
          const SizedBox(height: 10),
          _Bullet(label: 'Unlimited virtual closet storage'),
          const SizedBox(height: 10),
          _Bullet(label: 'Early access to luxury drops'),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String label;
  const _Bullet({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle, color: AppColors.sage, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                ),
          ),
        ),
      ],
    );
  }
}

/// "ACCEPT OFFER - $5.00/MONTH" — 50% off the current plan for one period
/// (mirrors backend RETENTION_DISCOUNT_PCT). Falls back to a generic label
/// while the subscription is loading.
String _offerLabel(WidgetRef ref) {
  final sub = ref.watch(subscriptionProvider).valueOrNull;
  final cents = sub?.priceCents;
  if (cents == null) return 'ACCEPT OFFER - 50% OFF';
  final unit = sub!.plan == 'pro_yearly' ? 'YEAR' : 'MONTH';
  return 'ACCEPT OFFER - \$${(cents / 2 / 100).toStringAsFixed(2)}/$unit';
}
