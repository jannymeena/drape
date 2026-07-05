import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../billing_service.dart';
import '../models/billing.dart';

/// All charges/credits (`GET /billing/history`). Invoice PDF download is a
/// future enhancement — the backend stores invoice numbers, not documents.
class BillingHistoryScreen extends ConsumerWidget {
  static const path = 'billing-history';
  static const name = 'profile_billing_history';

  const BillingHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(billingHistoryProvider);
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
                error: (e, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      e is ApiException
                          ? e.message
                          : "We couldn't load your billing history.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
                data: (records) => records.isEmpty
                    ? Center(
                        child: Text(
                          'No charges yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          Text(
                            'Your DRAPE invoices and receipts.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 20),
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: AppColors.taupeSoft
                                      .withValues(alpha: 0.4)),
                            ),
                            child: Column(
                              children: [
                                for (int i = 0; i < records.length; i++) ...[
                                  _InvoiceRow(record: records[i]),
                                  if (i < records.length - 1)
                                    Divider(
                                      height: 1,
                                      thickness: 1,
                                      color: AppColors.taupeSoft
                                          .withValues(alpha: 0.3),
                                      indent: 16,
                                      endIndent: 16,
                                    ),
                                ],
                              ],
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

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Billing History',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const SizedBox(width: 36),
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

class _InvoiceRow extends StatelessWidget {
  final BillingRecord record;
  const _InvoiceRow({required this.record});

  Color get _statusFg => switch (record.status) {
        'refunded' => AppColors.gold,
        'failed' => AppColors.error,
        _ => AppColors.sage,
      };

  String get _statusLabel =>
      record.amountCents < 0 ? 'CREDIT' : record.status.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final amount = record.amountCents;
    final sign = amount < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDate(record.occurredAt),
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(record.description,
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusFg.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _statusLabel,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: _statusFg,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    if (record.invoiceNumber != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        record.invoiceNumber!,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(color: AppColors.taupe),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Text(
            '$sign\$${(amount.abs() / 100).toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
