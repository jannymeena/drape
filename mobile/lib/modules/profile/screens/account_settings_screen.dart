import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section.dart';
import 'delete_account_screen.dart';
import 'edit_profile_screen.dart';
import 'email_password_settings_screen.dart';

class AccountSettingsScreen extends StatelessWidget {
  static const path = 'account';
  static const name = 'profile_account';

  const AccountSettingsScreen({super.key});

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
                  Center(
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          width: 96,
                          height: 96,
                          decoration: BoxDecoration(
                            color: AppColors.tanFixed,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.checkroom,
                              color: AppColors.espresso, size: 48),
                        ),
                        Container(
                          width: 30,
                          height: 30,
                          decoration: const BoxDecoration(
                            color: AppColors.espresso,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.camera_alt_outlined,
                              color: AppColors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Alex Chen',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  Center(
                    child: Text(
                      'Styler Tier: Gold Member',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SettingsSection(
                    title: 'PROFILE',
                    rows: [
                      SettingsRow(
                        icon: Icons.person_outline,
                        label: 'Edit Profile',
                        subtitle: 'Update name, photo, and personal info',
                        onTap: () => context.goNamed(EditProfileScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.mail_outline,
                        label: 'Email & Password',
                        subtitle: 'alex.chen@email.com · Last changed March 15',
                        onTap: () =>
                            context.goNamed(EmailPasswordSettingsScreen.name),
                      ),
                      SettingsRow(
                        icon: Icons.phone_outlined,
                        label: 'Phone Number',
                        subtitle: '+1 (555) 123-4567',
                        onTap: () => debugPrint('account: phone'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'CONNECTIONS',
                    rows: [
                      SettingsRow(
                        icon: Icons.link,
                        label: 'Connected Accounts',
                        subtitle: 'Google, Apple Sign-In',
                        onTap: () => debugPrint('account: connections'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'DANGER ZONE',
                    titleColor: AppColors.error,
                    background: AppColors.errorContainer.withValues(alpha: 0.4),
                    rows: [
                      SettingsRow(
                        icon: Icons.warning_amber_rounded,
                        label: 'Delete Account',
                        subtitle:
                            'Permanently delete your account and all data',
                        danger: true,
                        iconColor: AppColors.error,
                        iconBackground: AppColors.errorContainer,
                        onTap: () => context.goNamed(DeleteAccountScreen.name),
                      ),
                    ],
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
              'Account',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Icon(Icons.lock_outline, color: AppColors.espresso),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
