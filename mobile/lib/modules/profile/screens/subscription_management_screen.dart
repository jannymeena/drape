import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/cancellation_reason_sheet.dart';
import 'billing_history_screen.dart';
import 'compare_plans_screen.dart';
import 'payment_methods_screen.dart';
import 'retention_offer_screen.dart';

class SubscriptionManagementScreen extends StatelessWidget {
  static const path = 'subscription';
  static const name = 'profile_subscription';

  const SubscriptionManagementScreen({super.key});

  Future<void> _onCancel(BuildContext context) async {
    final reason = await showCancellationReasonSheet(context);
    if (reason != null && context.mounted) {
      debugPrint('cancel: reason=$reason');
      context.goNamed(RetentionOfferScreen.name);
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
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _PlanCard(
                    onChangePlan: () => context.goNamed(ComparePlansScreen.name),
                  ),
                  const SizedBox(height: 20),
                  _SectionHeader(label: 'Payment Method'),
                  const SizedBox(height: 8),
                  _CardOnFile(
                    onUpdate: () => context.goNamed(PaymentMethodsScreen.name),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: TextButton(
                      onPressed: () =>
                          context.goNamed(PaymentMethodsScreen.name),
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
                  _SectionHeader(label: 'Billing History'),
                  const SizedBox(height: 8),
                  _MiniInvoice(date: 'May 3, 2026', amount: r'$149.99'),
                  _MiniInvoice(date: 'May 3, 2025', amount: r'$149.99'),
                  _MiniInvoice(date: 'May 3, 2024', amount: r'$149.99'),
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
                  Container(
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
                          onTap: () => _onCancel(context),
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

class _PlanCard extends StatelessWidget {
  final VoidCallback onChangePlan;
  const _PlanCard({required this.onChangePlan});

  @override
  Widget build(BuildContext context) {
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
                  color: AppColors.gold,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'DRAPE PRO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.espressoDark,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppColors.sage, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Active',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.sageContent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Annual Plan',
              style: Theme.of(context).textTheme.titleLarge),
          Text(
            r'$149.99/year',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Next billing: May 3, 2027',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              OutlinedButton(
                onPressed: onChangePlan,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.espresso),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                ),
                child: Text(
                  'Change Plan',
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
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _CardOnFile extends StatelessWidget {
  final VoidCallback onUpdate;
  const _CardOnFile({required this.onUpdate});

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '•••• •••• •••• 4242',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        letterSpacing: 2,
                      ),
                ),
                Text(
                  'Expiry 05/28',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onUpdate,
            child: Text(
              'Update',
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
  final String date;
  final String amount;
  const _MiniInvoice({required this.date, required this.amount});

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
                Text(date, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  'Download PDF',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.espresso,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ],
            ),
          ),
          Text(amount, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}
