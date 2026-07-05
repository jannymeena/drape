import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../billing_service.dart';
import '../models/billing.dart';

/// Stored payment methods (`GET/POST /payment-methods`). "Add card" collects
/// the number only to derive a token — in dev the mock provider mints a visa
/// from it; the real Stripe tokenization SDK lands with 11c.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  static const path = 'payment-methods';
  static const name = 'profile_payment_methods';

  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() =>
      _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  bool _adding = false;

  Future<void> _addCard() async {
    final number = await _promptCardNumber(context);
    if (number == null || !mounted) return;
    setState(() => _adding = true);
    try {
      await ref
          .read(billingServiceProvider)
          .addPaymentMethod('tok_${number.replaceAll(' ', '')}');
      ref.invalidate(paymentMethodsProvider);
      if (!mounted) return;
      showDrapeToast(context, 'Payment method added');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(paymentMethodsProvider);
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
                    'SAVED METHODS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  ...async.when(
                    loading: () => const [
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.espresso),
                        ),
                      ),
                    ],
                    error: (e, _) => [
                      Text(
                        e is ApiException
                            ? e.message
                            : "We couldn't load your payment methods.",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    data: (methods) => methods.isEmpty
                        ? [
                            Text(
                              'No payment methods yet — add one below.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ]
                        : [
                            for (final m in methods) ...[
                              _CardRow(method: m),
                              const SizedBox(height: 10),
                            ],
                          ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'ADD NEW METHOD',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  _MethodTile(
                    icon: Icons.credit_card,
                    label: _adding ? 'Adding…' : 'Credit or Debit Card',
                    onTap: _adding ? null : _addCard,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline,
                            color: AppColors.sage, size: 18),
                        const SizedBox(height: 6),
                        Text(
                          'Your billing information is encrypted and processed securely.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
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

/// Minimal card-number prompt. Dev-only UX: the mock provider only needs the
/// last 4 digits; the Stripe SDK sheet replaces this in 11c.
Future<String?> _promptCardNumber(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: AppColors.ivory,
      title: const Text('Add card'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Card number'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final value = controller.text.trim();
            Navigator.of(dialogContext).pop(value.isEmpty ? null : value);
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
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
              'Payment Methods',
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

class _CardRow extends StatelessWidget {
  final PaymentMethodInfo method;
  const _CardRow({required this.method});

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
                  '${method.brand[0].toUpperCase()}${method.brand.substring(1)} •••• ${method.last4}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  'Expiry ${method.expMonth.toString().padLeft(2, '0')}/${method.expYear % 100}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (method.isDefault)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.sageDim,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'DEFAULT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.sageContent,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _MethodTile({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.espresso, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.add, color: AppColors.espresso, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
