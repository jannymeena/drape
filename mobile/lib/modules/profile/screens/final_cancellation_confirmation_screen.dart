import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../billing_service.dart';
import 'contact_us_screen.dart';

class FinalCancellationConfirmationScreen extends ConsumerWidget {
  static const path = 'final-cancellation';
  static const name = 'profile_final_cancellation';

  const FinalCancellationConfirmationScreen({super.key});

  /// "Keep My Pro Subscription" = accept the retention offer (un-cancels).
  Future<void> _keepPro(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(billingServiceProvider).acceptRetentionOffer();
      ref.invalidate(subscriptionProvider);
      if (!context.mounted) return;
      showDrapeToast(context, "You're staying on Pro!");
      context.pop();
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
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                children: [
                  _Progress(stepIndex: 2),
                  const SizedBox(height: 20),
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.18),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.gold, size: 30),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Confirm Cancellation',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _CurrentPlanCard(),
                  const SizedBox(height: 24),
                  Text(
                    'MEMBERSHIP DOWNGRADES',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  const _DowngradeRow(
                    icon: Icons.checkroom_outlined,
                    label: 'Wardrobe Limit',
                    subtitle: 'Reduced from Unlimited to 50 items',
                  ),
                  const SizedBox(height: 8),
                  const _DowngradeRow(
                    icon: Icons.visibility_off_outlined,
                    label: 'Hidden Items',
                    subtitle: '124 pieces will be archived',
                  ),
                  const SizedBox(height: 8),
                  const _DowngradeRow(
                    icon: Icons.auto_awesome,
                    label: 'AI Styling Limits',
                    subtitle: 'Only 3 suggestions per week',
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8EC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline,
                            color: AppColors.gold, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can reactivate your Pro subscription at any time before October 12th to keep your benefits and wardrobe access seamless.',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF7D5A11),
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Material(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () {
                        // The cancel API already ran at the reason step (soft
                        // cancel; Pro runs to period end) — this just closes
                        // the flow back to the subscription screen.
                        context.pop();
                        context.pop();
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: const SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: Center(
                          child: Text(
                            'Confirm Cancellation',
                            style: TextStyle(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DrapeButton.outlined(
                    label: 'Keep My Pro Subscription',
                    onPressed: () => _keepPro(context, ref),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: const [
                          TextSpan(text: 'Questions? '),
                          TextSpan(
                            text: 'Speak with a personal stylist',
                            style: TextStyle(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
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

class _Progress extends StatelessWidget {
  final int stepIndex; // 0-based
  const _Progress({required this.stepIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final filled = i == stepIndex;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 24,
          height: 3,
          decoration: BoxDecoration(
            color: filled ? AppColors.espresso : AppColors.tanFixed,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

class _CurrentPlanCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.tanFixed,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.style, color: AppColors.espresso),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CURRENT PLAN',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.taupe,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text('Pro Styling Annual',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(
                  'Active until October 12, 2024',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DowngradeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;

  const _DowngradeRow({
    required this.icon,
    required this.label,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.ink, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.titleSmall),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const Icon(Icons.arrow_downward, color: AppColors.error, size: 18),
        ],
      ),
    );
  }
}
