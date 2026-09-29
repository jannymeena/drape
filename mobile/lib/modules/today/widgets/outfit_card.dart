import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import 'outfit_item_grid.dart';
import 'why_this_works_block.dart';

/// View model for [OutfitCard]. Built from the `Outfit` DTO on the dashboard;
/// `items` carry the photo plus category/colour so photoless items render a
/// coloured silhouette instead of a blank cell.
class OutfitCardData {
  final String id;

  /// Section heading for the occasion, e.g. "For work".
  final String heading;
  final List<GarmentCell> items;
  final String reasoning;
  final bool favorited;
  final bool logged;

  /// Some pieces aren't owned yet: "Shop the look" replaces "Wear this".
  final bool shopTheLook;

  const OutfitCardData({
    required this.id,
    required this.heading,
    required this.items,
    required this.reasoning,
    this.favorited = false,
    this.logged = false,
    this.shopTheLook = false,
  });
}

class OutfitCard extends StatelessWidget {
  final OutfitCardData outfit;
  final VoidCallback? onRegenerate;
  final VoidCallback? onMix;
  final VoidCallback? onLogWorn;
  final VoidCallback? onShopTheLook;
  final VoidCallback? onFavorite;
  final VoidCallback? onLearnMore;

  /// AI is generating a replacement — overlays the grid and disables actions.
  final bool regenerating;

  /// A log-as-worn call is in flight — shows a spinner on the log button.
  final bool logging;

  const OutfitCard({
    super.key,
    required this.outfit,
    this.onRegenerate,
    this.onMix,
    this.onLogWorn,
    this.onShopTheLook,
    this.onFavorite,
    this.onLearnMore,
    this.regenerating = false,
    this.logging = false,
  });

  bool get _busy => regenerating || logging;

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
          Text(
            outfit.heading,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.espresso,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              OutfitItemGrid(cells: outfit.items),
              if (regenerating)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      color: AppColors.white.withValues(alpha: 0.72),
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(
                              color: AppColors.espresso, strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Restyling…',
                              style: TextStyle(
                                  color: AppColors.espresso,
                                  fontWeight: FontWeight.w600)),
                        ],
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
                  onPressed: _busy ? null : onRegenerate,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CardActionButton(
                  label: 'MIX',
                  onPressed: _busy ? null : onMix,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: outfit.shopTheLook
                    ? _CardActionButton(
                        label: 'SHOP THE LOOK',
                        filled: true,
                        onPressed: _busy ? null : onShopTheLook,
                      )
                    : _CardActionButton(
                        label: outfit.logged ? 'WORN TODAY' : 'WEAR THIS',
                        filled: true,
                        loading: logging,
                        // Worn outfits can be re-logged (idempotent server-side),
                        // but disable while any action on this card is in flight.
                        onPressed: _busy ? null : onLogWorn,
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
  final bool loading;
  final VoidCallback? onPressed;

  const _CardActionButton({
    required this.label,
    this.filled = false,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final bg = filled
        ? (disabled ? AppColors.taupeSoft : AppColors.espresso)
        : Colors.transparent;
    final fg = filled
        ? AppColors.white
        : (disabled ? AppColors.taupe : AppColors.espresso);

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
            child: loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Text(
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
