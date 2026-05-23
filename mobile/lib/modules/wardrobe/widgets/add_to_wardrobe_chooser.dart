import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

enum AddToWardrobeChoice { upload, scan, manual }

class AddToWardrobeChooser extends StatelessWidget {
  /// Free-tier capacity. Both null → the capacity banner is hidden (SP1, where
  /// the tier-gated cap isn't sourced yet); SP2 wires real values.
  final int? used;
  final int? remaining;
  final ValueChanged<AddToWardrobeChoice> onChoice;
  final VoidCallback? onUpgrade;

  const AddToWardrobeChooser({
    super.key,
    this.used,
    this.remaining,
    required this.onChoice,
    this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      children: [
        Text(
          'How would you like to add?',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 6),
        Text(
          'The more items you add, the better your daily outfits.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (used != null && remaining != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF8EC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0x4DC8901C)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline,
                    color: Color(0xFFC8901C), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'You have $used items. Add $remaining more to reach your limit.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF7D5A11),
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: onUpgrade,
                        child: Text(
                          'Upgrade for unlimited storage',
                          style:
                              Theme.of(context).textTheme.labelLarge?.copyWith(
                                    color: AppColors.espresso,
                                    decoration: TextDecoration.underline,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        _ChoiceCard(
          icon: Icons.photo_library_outlined,
          title: 'Upload Photos',
          body:
              'Add multiple clothes at once from your camera roll. Fastest way to build your wardrobe.',
          accent: const _BestForBadge(),
          highlighted: true,
          onTap: () => onChoice(AddToWardrobeChoice.upload),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.qr_code_scanner_outlined,
          title: 'Scan New Item',
          body: 'Point your camera at any garment for instant AI tagging.',
          onTap: () => onChoice(AddToWardrobeChoice.scan),
        ),
        const SizedBox(height: 12),
        _ChoiceCard(
          icon: Icons.edit_outlined,
          title: 'Add Manually',
          body: 'Detail every stitch, fabric, and origin.',
          onTap: () => onChoice(AddToWardrobeChoice.manual),
        ),
        const SizedBox(height: 20),
        Row(
          children: const [
            Expanded(child: _PerkPill(icon: Icons.lock_outline, label: 'Private to you')),
            SizedBox(width: 8),
            Expanded(child: _PerkPill(icon: Icons.auto_awesome, label: 'AI auto-tags each item')),
            SizedBox(width: 8),
            Expanded(child: _PerkPill(icon: Icons.delete_outline, label: 'Delete anytime')),
          ],
        ),
      ],
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  final Widget? accent;
  final bool highlighted;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.onTap,
    this.accent,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: highlighted ? AppColors.espresso : AppColors.taupeSoft,
          width: highlighted ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  color: AppColors.ivoryDim,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppColors.espresso, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(body,
                        style: Theme.of(context).textTheme.bodySmall),
                    if (accent != null) ...[
                      const SizedBox(height: 8),
                      accent!,
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}

class _BestForBadge extends StatelessWidget {
  const _BestForBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sage,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'BEST FOR 10+ ITEMS',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.white,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _PerkPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PerkPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.ivory,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.taupeSoft),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.sage, size: 16),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
