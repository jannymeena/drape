import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

Future<void> showPrivacySheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _PrivacySheet(),
  );
}

class _PrivacySheet extends StatelessWidget {
  const _PrivacySheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.tanFixed,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.shield_outlined,
                    color: AppColors.sage, size: 32),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.inkSoft),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'How ZOURA Protects Your Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Divider(height: 32, color: AppColors.taupeSoft),
            Text(
              'Your Privacy Matters',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.espresso,
                  ),
            ),
            const SizedBox(height: 16),
            const _Bullet(
              title: 'Stored on:',
              body: 'Your device + encrypted cloud backup (AWS Canada ca-central-1)',
            ),
            const SizedBox(height: 12),
            const _Bullet(
              title: 'Encryption:',
              body: 'AES-256 military-grade encryption at rest',
            ),
            const SizedBox(height: 12),
            const _Bullet(
              title: 'Access:',
              body: 'Only you. No ZOURA employee can view your measurements.',
            ),
            const SizedBox(height: 24),
            DrapeButton.outlined(
              label: 'Learn More',
              onPressed: () => debugPrint('privacy: learn more'),
              leading: const Icon(Icons.file_download_outlined,
                  size: 18, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            DrapeButton(
              label: 'Got It',
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String title;
  final String body;
  const _Bullet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(Icons.check_circle, color: AppColors.sage, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink,
                  ),
              children: [
                TextSpan(
                  text: '$title ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
