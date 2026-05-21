import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class BillingHistoryScreen extends StatelessWidget {
  static const path = 'billing-history';
  static const name = 'profile_billing_history';

  const BillingHistoryScreen({super.key});

  static const _invoices = <_Invoice>[
    _Invoice(date: 'May 3, 2026', amount: r'$149.99', status: _InvoiceStatus.paid),
    _Invoice(date: 'May 3, 2025', amount: r'$149.99', status: _InvoiceStatus.paid),
    _Invoice(date: 'May 3, 2024', amount: r'$149.99', status: _InvoiceStatus.paid),
    _Invoice(date: 'May 3, 2023', amount: r'$149.99', status: _InvoiceStatus.paid),
    _Invoice(date: 'Aug 11, 2022', amount: r'$14.99', status: _InvoiceStatus.refunded),
    _Invoice(date: 'May 3, 2022', amount: r'$129.99', status: _InvoiceStatus.paid),
  ];

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
                  Text(
                    "Your DRAPE invoices and receipts. Tap any row to download.",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _invoices.length; i++) ...[
                          _InvoiceRow(invoice: _invoices[i]),
                          if (i < _invoices.length - 1)
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: AppColors.taupeSoft.withValues(alpha: 0.3),
                              indent: 16,
                              endIndent: 16,
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => debugPrint('billing: export all'),
                      icon: const Icon(Icons.file_download_outlined,
                          size: 16, color: AppColors.espresso),
                      label: Text(
                        'Export All Invoices',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w700,
                            ),
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

enum _InvoiceStatus { paid, refunded, failed }

class _Invoice {
  final String date;
  final String amount;
  final _InvoiceStatus status;
  const _Invoice({
    required this.date,
    required this.amount,
    required this.status,
  });
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _InvoiceRow extends StatelessWidget {
  final _Invoice invoice;
  const _InvoiceRow({required this.invoice});

  Color get _statusFg => switch (invoice.status) {
        _InvoiceStatus.paid => AppColors.sage,
        _InvoiceStatus.refunded => AppColors.gold,
        _InvoiceStatus.failed => AppColors.error,
      };

  String get _statusLabel => switch (invoice.status) {
        _InvoiceStatus.paid => 'PAID',
        _InvoiceStatus.refunded => 'REFUNDED',
        _InvoiceStatus.failed => 'FAILED',
      };

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => debugPrint('billing: download ${invoice.date}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.date,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
              ],
            ),
            const Spacer(),
            Text(
              invoice.amount,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 8),
            const Icon(Icons.file_download_outlined,
                color: AppColors.taupe, size: 20),
          ],
        ),
      ),
    );
  }
}
