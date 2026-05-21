import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../widgets/faq_accordion.dart';
import 'contact_us_screen.dart';

/// Merges the `help_center_faqs` + `frequently_asked_questions` mockups
/// (same accordion UX) into one screen reachable from both the Help Center
/// hub and the Settings "FAQs" row.
class FaqsScreen extends StatefulWidget {
  static const path = 'faqs';
  static const name = 'profile_faqs';

  const FaqsScreen({super.key});

  @override
  State<FaqsScreen> createState() => _FaqsScreenState();
}

class _FaqsScreenState extends State<FaqsScreen> {
  int _category = 0;
  static const _categories = ['Getting Started', 'Wardrobe', 'Outfits'];

  static const _groups = <FaqGroup>[
    FaqGroup(
      title: 'Getting Started',
      icon: Icons.flag_outlined,
      items: [
        FaqItem(
          'How do I add items to my wardrobe?',
          'Scan with Camera, Upload Photos, or Manual Entry. All methods let you add tags, notes, and purchase details.',
        ),
        FaqItem(
          'What measurements do I need to provide?',
          'DRAPE uses 8 key measurements: Height, Weight, Chest/Bust, Waist, Hips, Inseam, Arm Length. Add these in Settings → Profile → Measurements.',
        ),
        FaqItem(
          'Can I sync multiple devices?',
          'Yes. DRAPE syncs your wardrobe data automatically across all logged-in devices.',
        ),
      ],
    ),
    FaqGroup(
      title: 'Wardrobe Management',
      icon: Icons.checkroom_outlined,
      items: [
        FaqItem(
          'How does the AI scanner tag items?',
          'The scanner uses computer vision to detect category, color, and formality, then suggests tags you can confirm or edit.',
        ),
      ],
    ),
    FaqGroup(
      title: 'AI Outfit Generation',
      icon: Icons.auto_awesome_outlined,
      items: [
        FaqItem(
          'How are my daily outfits chosen?',
          "DRAPE considers the weather, your calendar occasions, what you've worn recently, and your style profile.",
        ),
      ],
    ),
    FaqGroup(
      title: "Buy/Don't Buy & Shopping",
      icon: Icons.shopping_bag_outlined,
      items: [
        FaqItem(
          "What is Buy/Don't Buy?",
          'AI-powered pre-purchase analysis. Scan a barcode, upload a photo, or paste a product URL to get a fit + value + outfit-unlock verdict.',
        ),
      ],
    ),
    FaqGroup(
      title: 'Subscription & Billing',
      icon: Icons.receipt_long_outlined,
      items: [
        FaqItem(
          'How do I change my plan?',
          'Settings → Subscription → Change Plan. You can upgrade, downgrade, or cancel anytime.',
        ),
      ],
    ),
    FaqGroup(
      title: 'Privacy & Data',
      icon: Icons.shield_outlined,
      items: [
        FaqItem(
          'Where is my data stored?',
          'All data is stored encrypted in Canada (AWS ca-central-1) in compliance with PIPEDA. We never sell your data.',
        ),
      ],
    ),
    FaqGroup(
      title: 'Technical Issues',
      icon: Icons.build_outlined,
      items: [
        FaqItem(
          'The scanner is not detecting my item',
          'Ensure good lighting and a plain background. If confidence stays low, use Manual Entry instead.',
        ),
      ],
    ),
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
                  _HeroBanner(),
                  const SizedBox(height: 16),
                  _SearchField(),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, i) => _CategoryPill(
                        label: _categories[i],
                        selected: i == _category,
                        onTap: () => setState(() => _category = i),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < _groups.length; i++)
                    FaqAccordion(group: _groups[i], initiallyExpanded: i == 0),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      "Can't find what you're looking for?",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DrapeButton(
                    label: 'Contact Support',
                    onPressed: () => context.goNamed(ContactUsScreen.name),
                    leading: const Icon(Icons.mail_outline,
                        color: AppColors.white, size: 18),
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
              'FAQs',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          const Icon(Icons.search, color: AppColors.espresso),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.espressoDeep,
        borderRadius: BorderRadius.circular(14),
      ),
      alignment: Alignment.bottomLeft,
      padding: const EdgeInsets.all(16),
      child: Text(
        'Atelier Assistance',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.brandText,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
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
                hintText: 'Search FAQs...',
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

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.tanFixed,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: selected ? AppColors.white : AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
