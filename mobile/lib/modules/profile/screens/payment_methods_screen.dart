import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

class PaymentMethodsScreen extends StatelessWidget {
  static const path = 'payment-methods';
  static const name = 'profile_payment_methods';

  const PaymentMethodsScreen({super.key});

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
                    'CURRENT METHOD',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const _CardRow(),
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
                    icon: Icons.apple,
                    label: 'Apple Pay',
                    onTap: () => debugPrint('payment: apple pay'),
                  ),
                  const SizedBox(height: 10),
                  _MethodTile(
                    icon: Icons.credit_card,
                    label: 'Credit or Debit Card',
                    onTap: () => debugPrint('payment: card'),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        const Icon(Icons.lock_outline,
                            color: AppColors.sage, size: 18),
                        const SizedBox(height: 6),
                        Text(
                          'Your billing information is encrypted and processed securely by Stripe.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  DrapeButton(
                    label: 'Save Changes',
                    onPressed: () {
                      debugPrint('payment: save changes');
                      context.pop();
                    },
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
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.tanFixed,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person, color: AppColors.espresso, size: 16),
          ),
        ],
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    color: AppColors.espresso, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Mastercard',
                            style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(width: 6),
                        Text(
                          '• • • • 8842',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.inkSoft,
                                letterSpacing: 2,
                              ),
                        ),
                      ],
                    ),
                    Text(
                      'Expires 04/28',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.sageDim,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'PRIMARY',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.sageContent,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.location_on_outlined,
                  color: AppColors.taupe, size: 14),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Billing Address: 123 Editorial Way, Toronto, ON',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _TextAction(label: 'Update CVV', onTap: () => debugPrint('cvv')),
              _TextAction(
                label: 'Remove Card',
                color: AppColors.error,
                onTap: () => debugPrint('remove card'),
              ),
              _TextAction(label: 'Edit', onTap: () => debugPrint('edit card')),
            ],
          ),
        ],
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MethodTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryWarm,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.espresso, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: Theme.of(context).textTheme.titleSmall),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextAction extends StatelessWidget {
  final String label;
  final Color? color;
  final VoidCallback onTap;
  const _TextAction({required this.label, this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: color ?? AppColors.ink,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: color ?? AppColors.ink,
            ),
      ),
    );
  }
}
