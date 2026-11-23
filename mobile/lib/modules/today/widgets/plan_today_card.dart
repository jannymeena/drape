import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import 'dashed_outline.dart';
import 'outfit_card.dart';
import 'outfit_card_sized.dart';

/// Today's outfit slot when the day isn't planned: Today styles outfits for
/// the day's plan, so it asks what's on first. Tapping it opens Plan the day.
///
/// Exactly an outfit card's size ([OutfitCardSized]), so the carousel keeps
/// its height when the looks replace it.
class PlanTodayCard extends StatelessWidget {
  final VoidCallback onPlan;

  const PlanTodayCard({super.key, required this.onPlan});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return OutfitCardSized(
      child: Semantics(
        button: true,
        label: "What's on today? Plan today to get your outfits.",
        excludeSemantics: true,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.all(Radius.circular(20)),
            boxShadow: todayCardShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onPlan,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: DashedOutline(
                        color: AppColors.taupeSoft,
                        fill: AppColors.ivoryWarm,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.event_note_outlined,
                                size: 40,
                                color: AppColors.taupe,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "What's on today?",
                                textAlign: TextAlign.center,
                                style: AppTypography.sectionTitle,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pick an occasion and we’ll style up to '
                                'three looks from your wardrobe for it.',
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  color: AppColors.taupe,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const _PlanButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The card's CTA, styled like the outfit card's lead "Wear this". The
/// whole card is the tap target, so this only draws.
class _PlanButton extends StatelessWidget {
  const _PlanButton();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        gradient: LinearGradient(
          colors: [Color(0xFF7B5238), AppColors.espresso],
        ),
        boxShadow: todayCardShadow,
      ),
      child: SizedBox(
        height: 48,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, size: 18, color: AppColors.white),
              const SizedBox(width: 8),
              Text(
                'Plan today',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: AppColors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
