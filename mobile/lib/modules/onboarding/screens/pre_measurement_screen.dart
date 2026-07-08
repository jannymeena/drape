import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/analytics_screen_view.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/privacy_sheet.dart';
import '../widgets/skip_confirmation_sheet.dart';
import 'height_input_screen.dart';
import 'wardrobe_setup_screen.dart';

class PreMeasurementScreen extends ConsumerWidget {
  static const path = '/onboarding/pre-measurement';
  static const name = 'pre_measurement';

  const PreMeasurementScreen({super.key});

  Future<void> _onSkip(BuildContext context, WidgetRef ref) async {
    final analytics = ref.read(analyticsProvider);
    analytics.capture(AnalyticsEvents.skipConfirmationShown, {
      'source': 'pre_measurement',
    });
    final confirmed = await showSkipConfirmationSheet(context);
    analytics.capture(AnalyticsEvents.skipConfirmationAction, {
      'action': confirmed ? 'skipped' : 'continued',
    });
    if (confirmed) {
      analytics.capture(AnalyticsEvents.measurementsSkipped);
    }
    if (confirmed && context.mounted) {
      context.goNamed(WardrobeSetupScreen.name);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnalyticsScreenView(
      event: AnalyticsEvents.preMeasurementViewed,
      child: Scaffold(
        appBar: DrapeAppBar(
          actions: [
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.tanFixed,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'STEP 2 OF 3',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.espressoDark,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            children: [
              Text(
                'Build Your Personal Avatar',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 12),
              Text.rich(
                TextSpan(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
                  children: const [
                    TextSpan(
                      text:
                          'This 8-minute process builds an avatar calibrated to ',
                    ),
                    TextSpan(
                      text: 'YOUR',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          ' exact body — so every outfit DRAPE suggests actually fits you.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 200,
                  color: AppColors.espressoDark.withValues(alpha: 0.9),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.accessibility_new,
                    color: AppColors.tan,
                    size: 80,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const _ValueProp(
                icon: Icons.local_florist_outlined,
                title: 'Outfits that actually fit you',
                body: 'Not a generic mannequin. Your exact proportions.',
              ),
              const SizedBox(height: 12),
              const _ValueProp(
                icon: Icons.auto_awesome_outlined,
                title: 'More accurate AI suggestions',
                body: 'DRAPE considers your shape when styling.',
              ),
              const SizedBox(height: 12),
              const _ValueProp(
                icon: Icons.refresh,
                title: 'Update anytime, takes seconds',
                body: 'Your avatar improves every time you update.',
              ),
              const SizedBox(height: 20),
              InkWell(
                onTap: () => showPrivacySheet(context),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ivoryWarm,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline,
                        color: AppColors.sage,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Stored privately on Canadian servers · Never shared',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              DrapeButton(
                label: 'Begin Measurements',
                onPressed: () {
                  ref
                      .read(analyticsProvider)
                      .capture(AnalyticsEvents.measurementsStarted);
                  context.pushNamed(HeightInputScreen.name);
                },
                leading: const Icon(
                  Icons.arrow_forward,
                  color: AppColors.white,
                  size: 18,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => _onSkip(context, ref),
                  child: Column(
                    children: [
                      Text(
                        'Skip for now',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                      ),
                      Text(
                        '(You can complete this later in your profile)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ValueProp extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _ValueProp({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft),
      ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
