import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'outfit_item_grid.dart';
import 'why_this_works_block.dart';

/// Mock outfit data model used during Phase C (pre-API).
class OutfitCardData {
  final String id;
  final String occasion;
  final List<String> itemImageUrls;
  final String reasoning;
  final bool favorited;

  const OutfitCardData({
    required this.id,
    required this.occasion,
    required this.itemImageUrls,
    required this.reasoning,
    this.favorited = false,
  });
}

class OutfitCard extends StatelessWidget {
  final OutfitCardData outfit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onMix;
  final VoidCallback? onLogWorn;
  final VoidCallback? onFavorite;
  final VoidCallback? onLearnMore;

  const OutfitCard({
    super.key,
    required this.outfit,
    this.onRegenerate,
    this.onMix,
    this.onLogWorn,
    this.onFavorite,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2E8),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2A1810),
            blurRadius: 48,
            offset: Offset(0, 24),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              OutfitItemGrid(imageUrls: outfit.itemImageUrls),
              Positioned(
                top: 12,
                left: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.tanFixed,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    outfit.occasion.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.espresso,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: _FavoriteButton(
                  filled: outfit.favorited,
                  onTap: onFavorite,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          WhyThisWorksBlock(
            reasoning: outfit.reasoning,
            onLearnMore: onLearnMore,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _CardActionButton(
                  label: 'REGENERATE',
                  onPressed: onRegenerate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardActionButton(
                  label: 'MIX',
                  onPressed: onMix,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardActionButton(
                  label: 'LOG AS WORN',
                  filled: true,
                  onPressed: onLogWorn,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardActionButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onPressed;

  const _CardActionButton({
    required this.label,
    this.filled = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bg = filled ? AppColors.espresso : Colors.transparent;
    final fg = filled ? AppColors.white : AppColors.espresso;

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.taupeSoft),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 44,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: fg,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FavoriteButton extends StatelessWidget {
  final bool filled;
  final VoidCallback? onTap;

  const _FavoriteButton({required this.filled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            color: filled ? AppColors.gold : AppColors.espresso,
            size: 20,
          ),
        ),
      ),
    );
  }
}
