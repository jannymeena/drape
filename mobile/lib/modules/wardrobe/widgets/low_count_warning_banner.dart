import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';

/// Session-scoped dismissal for [LowCountWarningBanner] — the mockup's close X
/// hides it until the next app launch (no backend persistence, unlike the
/// Today starter banner's 7-day dismissal).
final lowCountBannerDismissedProvider = StateProvider<bool>((_) => false);

/// Low-wardrobe-count warning — mirrors the `wardrobe_with_low_count_warning`
/// mockup: filled warning icon, "Add at least 10 items…" headline,
/// "You have N items." subline, progress toward [goalItems], and a full-width
/// SCAN MORE ITEMS CTA. Shown on the grid when the wardrobe holds fewer than
/// [goalItems] real items and the starter-wardrobe banner no longer applies.
class LowCountWarningBanner extends StatelessWidget {
  final int itemCount;
  final int goalItems;
  final VoidCallback onScanMore;
  final VoidCallback onDismiss;

  const LowCountWarningBanner({
    super.key,
    required this.itemCount,
    this.goalItems = 10,
    required this.onScanMore,
    required this.onDismiss,
  });

  // Mockup palette (warmer than the capacity banner's amber).
  static const _amber = Color(0xFFC8A060);
  static const _track = Color(0xFFE8D8C8);
  static const _title = Color(0xFF2A1810);
  static const _subtitle = Color(0xFF6B5848);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _amber),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.warning_rounded, color: _amber, size: 22),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add at least $goalItems items for better outfit '
                      'suggestions.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: _title,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'You have $itemCount '
                      '${itemCount == 1 ? 'item' : 'items'}.',
                      style: textTheme.bodyMedium?.copyWith(color: _subtitle),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: onDismiss,
                child: const Icon(Icons.close, color: _amber, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value:
                  goalItems == 0 ? 0 : (itemCount / goalItems).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: _track,
              valueColor: const AlwaysStoppedAnimation<Color>(_amber),
            ),
          ),
          const SizedBox(height: 12),
          Material(
            color: _amber,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onScanMore,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'SCAN MORE ITEMS',
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
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
