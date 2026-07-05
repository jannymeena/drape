import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../billing_service.dart';
import '../models/billing.dart';
import '../widgets/cancellation_reason_sheet.dart';
import 'billing_history_screen.dart';
import 'compare_plans_screen.dart';
import 'payment_methods_screen.dart';
import 'retention_offer_screen.dart';

/// Subscription hub (`GET /subscription`). Cancellation is the backend's
/// 3-step flow: reason sheet → `POST /subscription/cancel` (soft — Pro runs to
/// period end) → retention offer screen (accept un-cancels, decline confirms).
class SubscriptionManagementScreen extends ConsumerWidget {
  static const path = 'subscription';
  static const name = 'profile_subscription';

  const SubscriptionManagementScreen({super.key});

  Future<void> _onCancel(BuildContext context, WidgetRef ref) async {
    final reason = await showCancellationReasonSheet(context);
    if (reason == null || !context.mounted) return;
    try {
      await ref.read(billingServiceProvider).cancel(reason: reason);
      ref.invalidate(subscriptionProvider);
      if (!context.mounted) return;
      context.goNamed(RetentionOfferScreen.name);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionProvider);
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: async.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
                error: (e, _) => _ErrorState(
                  message: e is ApiException
                      ? e.message
                      : "We couldn't load your subscription.",
                  onRetry: () => ref.invalidate(subscriptionProvider),
                ),
                data: (sub) => _Body(
                  subscription: sub,
                  onCancel: () => _onCancel(context, ref),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final SubscriptionInfo subscription;
  final VoidCallback onCancel;
  const _Body({required this.subscription, required this.onCancel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final methods = ref.watch(paymentMethodsProvider).valueOrNull;
    final history = ref.watch(billingHistoryProvider).valueOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        _PlanCard(
          subscription: subscription,
          onChangePlan: () => context.goNamed(ComparePlansScreen.name),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(label: 'Payment Method'),
        const SizedBox(height: 8),
        _CardOnFile(
          method: (methods?.isNotEmpty ?? false) ? methods!.first : null,
          onUpdate: () => context.goNamed(PaymentMethodsScreen.name),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => context.goNamed(PaymentMethodsScreen.name),
            child: Text(
              'Update Payment Method',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _SectionHeader(label: 'Billing History'),
        const SizedBox(height: 8),
        if (history == null || history.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'No charges yet.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          for (final record in history.take(3))
            _MiniInvoice(record: record),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.goNamed(BillingHistoryScreen.name),
            icon: const Icon(Icons.arrow_forward,
                size: 14, color: AppColors.espresso),
            label: Text(
              'View All Invoices',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (subscription.isPro && !subscription.cancelAtPeriodEnd)
          _CancelBlock(onCancel: onCancel),
      ],
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
            child: Text(
              'Subscription',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

String _formatDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[d.month - 1]} ${d.day}, ${d.year}';
}

String _money(int cents) {
  final sign = cents < 0 ? '-' : '';
  return '$sign\$${(cents.abs() / 100).toStringAsFixed(2)}';
}

class _PlanCard extends StatelessWidget {
  final SubscriptionInfo subscription;
  final VoidCallback onChangePlan;
  const _PlanCard({required this.subscription, required this.onChangePlan});

  @override
  Widget build(BuildContext context) {
    final sub = subscription;
    final isPro = sub.isPro;
    final planLabel = !isPro
        ? 'Free Plan'
        : sub.plan == 'pro_yearly'
            ? 'Annual Plan'
            : 'Monthly Plan';
    final price = !isPro || sub.priceCents == null
        ? r'$0'
        : '${_money(sub.priceCents!)}/${sub.plan == 'pro_yearly' ? 'year' : 'month'}';
    final renewal = sub.currentPeriodEnd == null
        ? null
        : sub.cancelAtPeriodEnd
            ? 'Pro ends: ${_formatDate(sub.currentPeriodEnd!)}'
            : 'Next billing: ${_formatDate(sub.currentPeriodEnd!)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPro ? AppColors.gold : AppColors.sand,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isPro ? 'DRAPE PRO' : 'FREE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.espressoDark,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              if (isPro)
                Row(
                  children: [
                    Icon(
                      sub.cancelAtPeriodEnd
                          ? Icons.hourglass_bottom
                          : Icons.check_circle,
                      color: sub.cancelAtPeriodEnd
                          ? AppColors.gold
                          : AppColors.sage,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sub.cancelAtPeriodEnd ? 'Ending' : 'Active',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: sub.cancelAtPeriodEnd
                                ? AppColors.goldDark
                                : AppColors.sageContent,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(planLabel, style: Theme.of(context).textTheme.titleLarge),
          Text(
            price,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  renewal ?? 'Upgrade to unlock unlimited styling.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: onChangePlan,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.espresso),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                child: Text(
                  isPro ? 'Change Plan' : 'Upgrade',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _CardOnFile extends StatelessWidget {
  final PaymentMethodInfo? method;
  final VoidCallback onUpdate;
  const _CardOnFile({required this.method, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(4),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.credit_card,
                color: AppColors.espresso, size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: method == null
                ? Text(
                    'No payment method on file',
                    style: Theme.of(context).textTheme.bodyMedium,
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•••• •••• •••• ${method!.last4}',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(letterSpacing: 2),
                      ),
                      Text(
                        'Expiry ${method!.expMonth.toString().padLeft(2, '0')}/${method!.expYear % 100}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
          GestureDetector(
            onTap: onUpdate,
            child: Text(
              method == null ? 'Add' : 'Update',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniInvoice extends StatelessWidget {
  final BillingRecord record;
  const _MiniInvoice({required this.record});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(record.occurredAt),
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  record.description,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(_money(record.amountCents),
              style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _CancelBlock extends StatelessWidget {
  final VoidCallback onCancel;
  const _CancelBlock({required this.onCancel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Need to cancel?',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            'If you cancel your subscription, you will lose access to the Pro Wardrobe Analyzer and unlimited style recommendations at the end of your current billing period.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: onCancel,
            child: Text(
              'Cancel Subscription',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.error,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 12),
            DrapeButton.outlined(
              label: 'Try again',
              onPressed: onRetry,
              fullWidth: false,
            ),
          ],
        ),
      ),
    );
  }
}
