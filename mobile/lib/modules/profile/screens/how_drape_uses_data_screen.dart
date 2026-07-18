import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';

class HowDrapeUsesDataScreen extends StatelessWidget {
  static const path = 'data-usage';
  static const name = 'profile_data_usage';

  const HowDrapeUsesDataScreen({super.key});

  static const _sections = <_DataSection>[
    _DataSection(
      icon: Icons.camera_alt_outlined,
      title: 'Wardrobe Photos',
      bullets: [
        'Stored encrypted in AWS Canada data centers.',
        'Never sold or used for training external AI models.',
        'Private, deleted within 30 days of account closure.',
        'Used only for styling and visualization.',
      ],
    ),
    _DataSection(
      icon: Icons.badge_outlined,
      title: 'ZOURA Profile',
      bullets: [
        'Stored on your device and encrypted cloud.',
        'AES-256 encryption secures measurements.',
        'Only you can access this sensitive data.',
        'Never shared with advertisers or third parties.',
      ],
    ),
    _DataSection(
      icon: Icons.access_time,
      title: 'Outfit History',
      bullets: [
        'History and preferences stored securely in Canada.',
        'Used exclusively to refine your suggestions.',
        'Export or delete your data anytime.',
      ],
    ),
    _DataSection(
      icon: Icons.timelapse,
      title: 'Data Retention',
      bullets: [
        '**Wardrobe Photos:** Kept until you choose to delete them.',
        '**Usage Analytics:** Retained for 2 years to improve your styling.',
        '**Account Data:** Kept until account deletion plus a 30-day grace period.',
      ],
    ),
  ];

  static const _dontDo = [
    'Never sell your personal data.',
    "Never use your photos for other users' AI training.",
    'Never share measurements with retailers.',
    'Never store data outside of Canadian jurisdiction.',
    'No biometric identification or surveillance.',
  ];

  static const _rights = [
    'Access',
    'Correction',
    'Deletion',
    'Transparency',
    'Complaints',
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.taupeSoft),
                          ),
                          alignment: Alignment.center,
                          child: const Text('🇨🇦', style: TextStyle(fontSize: 18)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: const BoxDecoration(
                            color: AppColors.espresso,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Icon(Icons.lock_outline,
                              color: AppColors.white, size: 16),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'How ZOURA Uses Your Data',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Plain English. No legal jargon. Just the facts.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  for (final s in _sections) ...[
                    _SectionCard(section: s),
                    const SizedBox(height: 12),
                  ],
                  _DontDoCard(items: _dontDo),
                  const SizedBox(height: 16),
                  _RightsCard(rights: _rights),
                  const SizedBox(height: 16),
                  _OutlinedAction(
                    icon: Icons.file_download_outlined,
                    label: 'Download Privacy Policy PDF',
                    onTap: () => debugPrint('privacy: download policy'),
                  ),
                  const SizedBox(height: 10),
                  _OutlinedAction(
                    icon: Icons.mail_outline,
                    label: 'Contact Privacy Team',
                    onTap: () => debugPrint('privacy: contact'),
                  ),
                  const SizedBox(height: 10),
                  _OutlinedAction(
                    icon: Icons.description_outlined,
                    label: 'Download Full Privacy Policy PDF',
                    onTap: () => debugPrint('privacy: download full policy'),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'ZOURA is PIPEDA compliant and stores all data in Canada 🇨🇦',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text.rich(
                      TextSpan(
                        style: Theme.of(context).textTheme.bodySmall,
                        children: const [
                          TextSpan(text: 'Questions? '),
                          TextSpan(
                            text: 'privacy@zoura.style',
                            style: TextStyle(
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

class _DataSection {
  final IconData icon;
  final String title;
  final List<String> bullets;
  const _DataSection({
    required this.icon,
    required this.title,
    required this.bullets,
  });
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
              'How ZOURA Uses Your Data',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
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

class _SectionCard extends StatelessWidget {
  final _DataSection section;
  const _SectionCard({required this.section});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(section.icon, color: AppColors.ink, size: 20),
              const SizedBox(width: 8),
              Text(section.title,
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          for (final b in section.bullets) ...[
            _Bullet(text: b),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) {
    final parts = text.split('**');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 3),
          child: Icon(Icons.check_circle, color: AppColors.sage, size: 14),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium,
              children: [
                for (int i = 0; i < parts.length; i++)
                  TextSpan(
                    text: parts[i],
                    style: i.isOdd
                        ? const TextStyle(fontWeight: FontWeight.w700)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DontDoCard extends StatelessWidget {
  final List<String> items;
  const _DontDoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: AppColors.error, size: 18),
              const SizedBox(width: 8),
              Text(
                "What We Don't Do",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(Icons.close, color: AppColors.error, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.onErrorContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

class _RightsCard extends StatelessWidget {
  final List<String> rights;
  const _RightsCard({required this.rights});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.balance, color: AppColors.ink, size: 18),
              const SizedBox(width: 8),
              Text('Your Rights (PIPEDA)',
                  style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: rights
                .map((r) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.sand,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        r,
                        style:
                            Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppColors.ink,
                                  fontWeight: FontWeight.w600,
                                ),
                      ),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OutlinedAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _OutlinedAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.taupeSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppColors.ink, size: 16),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
