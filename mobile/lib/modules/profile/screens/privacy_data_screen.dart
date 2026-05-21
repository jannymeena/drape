import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../widgets/settings_row.dart';
import '../widgets/settings_section.dart';
import 'delete_account_screen.dart';
import 'export_my_data_screen.dart';
import 'how_drape_uses_data_screen.dart';

class PrivacyDataScreen extends StatefulWidget {
  static const path = 'privacy-data';
  static const name = 'profile_privacy_data';

  const PrivacyDataScreen({super.key});

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  bool _twoFactor = false;

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
                  SettingsSection(
                    title: 'SECURITY',
                    rows: [
                      SettingsRow(
                        icon: Icons.shield_outlined,
                        label: 'Enable Two-Factor (2FA)',
                        subtitle: 'Adds an extra layer of protection to your style profile.',
                        trailing: Switch(
                          value: _twoFactor,
                          onChanged: (v) => setState(() => _twoFactor = v),
                          activeThumbColor: AppColors.espresso,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _ResidencyCard(
                    onLearnMore: () =>
                        context.goNamed(HowDrapeUsesDataScreen.name),
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'WHAT WE COLLECT',
                    rows: [
                      SettingsRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Wardrobe Photos',
                        trailing: _TrailingNote('Private S3 bucket'),
                      ),
                      SettingsRow(
                        icon: Icons.accessibility_new,
                        label: 'Body Measurements',
                        trailing: _TrailingNote('Encrypted at rest'),
                      ),
                      SettingsRow(
                        icon: Icons.show_chart,
                        label: 'Usage Patterns',
                        trailing: _TrailingNote('Outfit logs'),
                      ),
                      SettingsRow(
                        icon: Icons.verified_outlined,
                        iconColor: AppColors.sage,
                        iconBackground: AppColors.sageDim,
                        label: 'We never sell your data.',
                        trailing: const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'CONNECTED APPS',
                    rows: [
                      SettingsRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Google Calendar',
                        trailing: _RevokeButton(onTap: () => debugPrint('revoke gcal')),
                      ),
                      SettingsRow(
                        icon: Icons.camera_alt_outlined,
                        label: 'Instagram',
                        trailing: _RevokeButton(onTap: () => debugPrint('revoke ig')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SettingsSection(
                    title: 'YOUR RIGHTS (PIPEDA)',
                    rows: [
                      SettingsRow(
                        icon: Icons.download_outlined,
                        label: 'Access Your Data',
                        trailing: _RequestArrow(
                          label: 'Request',
                          color: AppColors.espresso,
                          onTap: () => context.goNamed(ExportMyDataScreen.name),
                        ),
                      ),
                      SettingsRow(
                        icon: Icons.edit_outlined,
                        label: 'Correct Your Data',
                        onTap: () => debugPrint('privacy: correct'),
                      ),
                      SettingsRow(
                        icon: Icons.delete_outline,
                        label: 'Delete Your Data',
                        trailing: _RequestArrow(
                          label: 'Delete',
                          color: AppColors.error,
                          onTap: () => context.goNamed(DeleteAccountScreen.name),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _PolicyLink(label: 'Privacy Policy', onTap: () => debugPrint('policy')),
                        ),
                        Container(width: 1, height: 28, color: AppColors.taupeSoft.withValues(alpha: 0.4)),
                        Expanded(
                          child: _PolicyLink(label: 'Terms of Service', onTap: () => debugPrint('terms')),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Questions? Contact our Privacy Officer',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'privacy@drape.app',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
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
              'Privacy & Security',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResidencyCard extends StatelessWidget {
  final VoidCallback onLearnMore;
  const _ResidencyCard({required this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.35),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.shield_outlined,
                color: AppColors.sage, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            'Your data stays in Canada.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.brandText,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.brandText.withValues(alpha: 0.7),
                  ),
              children: [
                const TextSpan(
                    text:
                        'Your data is stored in Canada (AWS ca-central-1) in compliance with PIPEDA. '),
                WidgetSpan(
                  alignment: PlaceholderAlignment.middle,
                  child: GestureDetector(
                    onTap: onLearnMore,
                    child: Text(
                      'Learn More',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.brandText,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.brandText,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TrailingNote extends StatelessWidget {
  final String label;
  const _TrailingNote(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.taupe,
          ),
    );
  }
}

class _RevokeButton extends StatelessWidget {
  final VoidCallback onTap;
  const _RevokeButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        'Revoke',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.underline,
              decorationColor: AppColors.error,
            ),
      ),
    );
  }
}

class _RequestArrow extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _RequestArrow({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.arrow_forward, color: color, size: 14),
        ],
      ),
    );
  }
}

class _PolicyLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PolicyLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
          ),
        ),
      ),
    );
  }
}
