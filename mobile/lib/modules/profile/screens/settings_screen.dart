import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../auth/auth_controller.dart';
import '../../auth/screens/welcome_screen.dart';
import '../settings_service.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section.dart';
import 'account_settings_screen.dart';
import 'billing_history_screen.dart';
import 'compare_plans_screen.dart';
import 'edit_measurements_screen.dart';
import 'edit_profile_screen.dart';
import 'email_password_settings_screen.dart';
import 'contact_us_screen.dart';
import 'export_my_data_screen.dart';
import 'faqs_screen.dart';
import 'feature_request_screen.dart';
import 'help_center_hub_screen.dart';
import 'notifications_preferences_screen.dart';
import 'payment_methods_screen.dart';
import 'privacy_data_screen.dart';
import 'report_bug_screen.dart';
import 'style_preferences_screen.dart';
import 'subscription_management_screen.dart';
import '../widgets/cancellation_reason_sheet.dart';
import 'retention_offer_screen.dart';

class SettingsScreen extends ConsumerWidget {
  static const path = 'settings';
  static const name = 'profile_settings';

  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  SettingsSection(
                    title: 'ACCOUNT',
                    rows: [
                      SettingsRow(
                        icon: Icons.person_outline,
                        label: 'Edit Profile',
                        onTap: () => context.goNamed(EditProfileScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.straighten,
                        label: 'Body Measurements',
                        onTap: () =>
                            context.goNamed(EditMeasurementsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.lock_outline,
                        label: 'Email/Password',
                        onTap: () =>
                            context.goNamed(EmailPasswordSettingsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        onTap: () => context.goNamed(AccountSettingsScreen.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'SUBSCRIPTION',
                    rows: [
                      SettingsRow(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Current Plan',
                        onTap: () =>
                            context.goNamed(SubscriptionManagementScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.compare_arrows,
                        label: 'Compare Plans',
                        onTap: () => context.goNamed(ComparePlansScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.credit_card_outlined,
                        label: 'Payment Method',
                        onTap: () => context.goNamed(PaymentMethodsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.receipt_long_outlined,
                        label: 'Billing History',
                        onTap: () => context.goNamed(BillingHistoryScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.cancel_outlined,
                        label: 'Cancel Subscription',
                        onTap: () async {
                          final reason =
                              await showCancellationReasonSheet(context);
                          if (reason != null && context.mounted) {
                            context.goNamed(RetentionOfferScreen.name);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'PREFERENCES',
                    rows: [
                      SettingsRow(
                        icon: Icons.notifications_outlined,
                        label: 'Notifications',
                        onTap: () => context
                            .goNamed(NotificationsPreferencesScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.straighten,
                        label: 'Units',
                        onTap: () => _showUnitsSheet(context, ref),
                      ),
                      SettingsRow(
                        icon: Icons.tune,
                        label: 'Style Preferences',
                        onTap: () =>
                            context.goNamed(StylePreferencesScreen.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'DATA & PRIVACY',
                    rows: [
                      SettingsRow(
                        icon: Icons.shield_outlined,
                        label: 'Privacy & Data',
                        onTap: () => context.goNamed(PrivacyDataScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.file_download_outlined,
                        label: 'Export My Data',
                        onTap: () => context.goNamed(ExportMyDataScreen.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'SUPPORT',
                    rows: [
                      SettingsRow(
                        icon: Icons.help_outline,
                        label: 'Help Center',
                        onTap: () => context.goNamed(HelpCenterHubScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.quiz_outlined,
                        label: 'FAQs',
                        onTap: () => context.goNamed(FaqsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.mail_outline,
                        label: 'Contact Us',
                        onTap: () => context.goNamed(ContactUsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.bug_report_outlined,
                        label: 'Report Bug',
                        onTap: () => context.goNamed(ReportBugScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.lightbulb_outline,
                        label: 'Feature Request',
                        onTap: () => context.goNamed(FeatureRequestScreen.name),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    rows: [
                      SettingsRow(
                        icon: Icons.logout,
                        label: 'Sign Out',
                        danger: true,
                        iconColor: AppColors.error,
                        iconBackground: AppColors.errorContainer,
                        onTap: () async {
                          // Revoke the refresh token server-side (best-effort)
                          // and clear local tokens + session, then return to
                          // Welcome — the router redirect bounces protected
                          // routes once the session flag flips.
                          await ref
                              .read(authControllerProvider.notifier)
                              .logout();
                          if (context.mounted) {
                            context.goNamed(WelcomeScreen.name);
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'DRAPE V1.0.0',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppColors.taupe,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Made with care in Canada 🇨🇦',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.taupe,
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

/// Bottom sheet to pick the measurement unit system. Persists `unit_system`
/// via PATCH /settings. (Persist-only for now — display conversion cm↔in is a
/// later, app-wide change.)
Future<void> _showUnitsSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.ivory,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _UnitsSheet(),
  );
}

class _UnitsSheet extends ConsumerStatefulWidget {
  const _UnitsSheet();

  @override
  ConsumerState<_UnitsSheet> createState() => _UnitsSheetState();
}

class _UnitsSheetState extends ConsumerState<_UnitsSheet> {
  static const _options = [
    ('metric', 'Metric', 'Centimetres · kilograms'),
    ('imperial', 'Imperial', 'Inches · pounds'),
  ];

  bool _saving = false;

  Future<void> _select(String unit) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(settingsServiceProvider)
          .updateSettings({'unit_system': unit});
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException
              ? e.message
              : "Couldn't save — check your connection."),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final current = ref.watch(settingsProvider).valueOrNull?.unitSystem;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Units', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Used across measurements and sizing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            for (final o in _options) ...[
              _UnitOption(
                label: o.$2,
                description: o.$3,
                selected: current == o.$1,
                onTap: _saving ? null : () => _select(o.$1),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback? onTap;

  const _UnitOption({
    required this.label,
    required this.description,
    required this.selected,
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
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.taupeSoft,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 2),
                    Text(description,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.espresso : AppColors.taupeSoft,
                size: 22,
              ),
            ],
          ),
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
              'Settings',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.espresso,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
