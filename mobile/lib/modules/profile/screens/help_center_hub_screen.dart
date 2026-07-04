import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import 'contact_us_screen.dart';
import 'faqs_screen.dart';

class HelpCenterHubScreen extends StatelessWidget {
  static const path = 'help-center';
  static const name = 'profile_help_center';

  const HelpCenterHubScreen({super.key});

  static const _categories = [
    ('Getting Started', Icons.auto_awesome_outlined),
    ('Wardrobe', Icons.checkroom_outlined),
    ('AI Styling', Icons.face_retouching_natural),
    ('Billing', Icons.credit_card_outlined),
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
                  _SearchField(),
                  const SizedBox(height: 16),
                  Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: AppColors.espressoDeep,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.bottomLeft,
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Curation Essentials',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.brandText,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.6,
                    children: [
                      for (final c in _categories)
                        _CategoryCard(
                          label: c.$1,
                          icon: c.$2,
                          onTap: () => context.goNamed(FaqsScreen.name),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'TROUBLESHOOTING',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taupe,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 72,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: const [
                        _TroubleCard(label: 'Sync Errors', icon: Icons.sync_problem),
                        SizedBox(width: 10),
                        _TroubleCard(label: 'Image Clarity', icon: Icons.image_outlined),
                        SizedBox(width: 10),
                        _TroubleCard(label: 'Login Issues', icon: Icons.lock_outline),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _StillNeedHelpCard(
                    onContact: () => context.goNamed(ContactUsScreen.name),
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
              'Help Center',
              textAlign: TextAlign.left,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Icon(Icons.settings_outlined, color: AppColors.espresso),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.taupe, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'How can we help you today?',
                hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.taupe,
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _CategoryCard({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.espresso, size: 18),
              ),
              Text(label, style: Theme.of(context).textTheme.titleSmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _TroubleCard extends StatelessWidget {
  final String label;
  final IconData icon;
  const _TroubleCard({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: AppColors.sage, size: 18),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
        ],
      ),
    );
  }
}

class _StillNeedHelpCard extends StatelessWidget {
  final VoidCallback onContact;
  const _StillNeedHelpCard({required this.onContact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            'Still need help?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.brandText,
                  fontStyle: FontStyle.italic,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Our master stylists are available for 1-on-1 consultations to perfect your digital wardrobe.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.75),
                ),
          ),
          const SizedBox(height: 16),
          Material(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onContact,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: Text(
                  'Contact Stylist',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.espressoDark,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
