import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../models/outfit.dart';
import 'outfit_collage.dart';

/// Ambient "espresso" shadow shared by every Today card (Stitch DESIGN.md §4:
/// blur 24, spread -4, 6% dark brown — never a Material drop shadow).
const todayCardShadow = [
  BoxShadow(
    color: Color(0x0F2A1810),
    blurRadius: 24,
    spreadRadius: -4,
    offset: Offset(0, 8),
  ),
];

/// A small badge on the hero image naming what the look was styled against
/// (e.g. "Rain-ready"), derived from the weather the outfit was generated for.
class OutfitWeatherBadge {
  final String label;
  final IconData icon;
  const OutfitWeatherBadge(this.label, this.icon);

  static OutfitWeatherBadge? fromWeather(WeatherContext? w) {
    if (w == null) return null;
    final c = w.condition.toLowerCase();
    if (c.contains('rain') || c.contains('drizzle') || c.contains('thunder')) {
      return const OutfitWeatherBadge('Rain-ready', Icons.water_drop_outlined);
    }
    if (c.contains('snow')) {
      return const OutfitWeatherBadge('Snow-ready', Icons.ac_unit);
    }
    if (w.feelsLikeC <= 5) {
      return const OutfitWeatherBadge('Cold-ready', Icons.thermostat_outlined);
    }
    if (w.feelsLikeC >= 26) {
      return const OutfitWeatherBadge('Heat-ready', Icons.wb_sunny_outlined);
    }
    return null;
  }
}

/// View model for [OutfitCard], built from the `Outfit` DTO via [fromOutfit].
/// `items` carry the photo plus category/colour so photoless items render a
/// coloured silhouette instead of a blank tile.
class OutfitCardData {
  final String id;

  /// Corner tag on the image — the look's dress level ("Smart casual") when
  /// the pieces agree on one, else the occasion.
  final String occasion;

  /// Serif headline under the image.
  final String title;
  final List<GarmentCell> items;

  /// Piece names, shown as chips under the reasoning line.
  final List<String> itemNames;
  final String reasoning;

  /// 0–100 compatibility from the stylist; hidden when null.
  final int? matchScore;
  final OutfitWeatherBadge? weatherBadge;
  final bool favorited;
  final bool logged;

  /// Some pieces aren't owned yet: "Shop the look" replaces "Wear this".
  final bool shopTheLook;

  const OutfitCardData({
    required this.id,
    required this.occasion,
    required this.items,
    required this.reasoning,
    String? title,
    this.itemNames = const [],
    this.matchScore,
    this.weatherBadge,
    this.favorited = false,
    this.logged = false,
    this.shopTheLook = false,
  }) : title = title ?? '$occasion look';

  factory OutfitCardData.fromOutfit(Outfit outfit) {
    return OutfitCardData(
      id: outfit.id,
      occasion: _dressLevel(outfit) ?? outfit.occasionLabel,
      title: outfit.title ?? '${outfit.occasionLabel} look',
      items: [
        for (final i in outfit.items)
          GarmentCell(
            imageUrl: i.primaryImageUrl,
            category: i.category,
            color: garmentColorFromName(i.colorName),
            buyUrl: i.productUrl,
          ),
      ],
      itemNames: [for (final i in outfit.items) i.name],
      reasoning: outfit.aiReasoningShort ?? '',
      matchScore: outfit.compatibilityScore,
      weatherBadge: OutfitWeatherBadge.fromWeather(outfit.weatherContext),
      logged: outfit.isLogged,
      favorited: outfit.isFavorite,
      shopTheLook: outfit.shopTheLook,
    );
  }

  /// Most common item formality (`smart_casual` → "Smart casual").
  static String? _dressLevel(Outfit outfit) {
    final counts = <String, int>{};
    for (final i in outfit.items) {
      final f = i.formality;
      if (f != null && f.isNotEmpty) counts[f] = (counts[f] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final top = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    final words = top.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  int get ownedCount => items.where((c) => c.buyUrl == null).length;
}

/// The Today carousel card (Stitch "Zoura Today"): hero collage with the dress
/// level, heart and weather badge; title + match; "Built from N items"; the
/// stylist's one-line reason; piece chips; the wear CTA; and the
/// Mix & match / Change it / Regenerate row.
class OutfitCard extends StatelessWidget {
  final OutfitCardData outfit;

  /// The lead look gets the filled "Wear this" CTA; the alternates a tonal
  /// "Wear this instead".
  final bool featured;
  final VoidCallback? onRegenerate;
  final VoidCallback? onMix;
  final VoidCallback? onChange;
  final VoidCallback? onLogWorn;
  final VoidCallback? onShopTheLook;
  final VoidCallback? onFavorite;
  final VoidCallback? onLearnMore;

  /// AI is generating a replacement — overlays the image and disables actions.
  final bool regenerating;

  /// A log-as-worn call is in flight — shows a spinner on the CTA.
  final bool logging;

  /// Fill a bounded parent height (the carousel's equal-height row), pinning
  /// the buttons to the bottom. Only valid under a bounded height.
  final bool expand;

  const OutfitCard({
    super.key,
    required this.outfit,
    this.featured = true,
    this.onRegenerate,
    this.onMix,
    this.onChange,
    this.onLogWorn,
    this.onShopTheLook,
    this.onFavorite,
    this.onLearnMore,
    this.regenerating = false,
    this.logging = false,
    this.expand = false,
  });

  bool get _busy => regenerating || logging;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final owned = outfit.ownedCount;
    final toShop = outfit.items.length - owned;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: todayCardShadow,
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              OutfitCollage(cells: outfit.items),
              if (regenerating)
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                top: 12,
                left: 12,
                child: _ImagePill(
                  child: Text(
                    outfit.occasion.toUpperCase(),
                    style: text.labelSmall?.copyWith(
                      color: AppColors.ink,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: _FavoriteButton(
                  filled: outfit.favorited,
                  onTap: onFavorite,
                ),
              ),
              if (outfit.weatherBadge != null)
                Positioned(
                  bottom: 12,
                  right: 12,
                  child: _ImagePill(
                    color: AppColors.ivoryDim.withValues(alpha: 0.95),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(outfit.weatherBadge!.icon,
                            size: 14, color: AppColors.sage),
                        const SizedBox(width: 4),
                        Text(
                          outfit.weatherBadge!.label,
                          style: text.labelSmall?.copyWith(
                            color: AppColors.ink,
                            fontSize: 11,
                            letterSpacing: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          _maybeExpanded(Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        outfit.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.sectionTitle,
                      ),
                    ),
                    if (outfit.matchScore != null) ...[
                      const SizedBox(width: 8),
                      _MatchPill(score: outfit.matchScore!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  toShop == 0
                      ? 'Built from ${_items(owned)} in your wardrobe'
                      : owned == 0
                          ? 'Styled from ${_pieces(toShop)} to shop'
                          : 'Built from ${_items(owned)} you own + $toShop to shop',
                  style: text.bodySmall?.copyWith(
                    color: AppColors.taupe,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (outfit.reasoning.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _ReasonRow(reasoning: outfit.reasoning, onTap: onLearnMore),
                ],
                if (outfit.itemNames.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final name in outfit.itemNames) _ItemChip(name),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                // Equal-height cards in the carousel: alternates with fewer
                // chips keep their buttons on the same baseline.
                if (expand) const Spacer(),
                _cta(),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.shuffle,
                        label: 'Mix & match',
                        onPressed: _busy ? null : onMix,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.tune,
                        label: 'Change it',
                        onPressed: _busy ? null : onChange,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _SecondaryAction(
                        icon: Icons.sync,
                        label: 'Regenerate',
                        onPressed: _busy ? null : onRegenerate,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _maybeExpanded(Widget child) =>
      expand ? Expanded(child: child) : child;

  Widget _cta() {
    if (outfit.shopTheLook) {
      return _PrimaryAction(
        icon: Icons.shopping_bag_outlined,
        label: 'Shop the look',
        filled: featured,
        onPressed: _busy ? null : onShopTheLook,
      );
    }
    return _PrimaryAction(
      icon: outfit.logged ? Icons.check : Icons.checkroom,
      label: outfit.logged
          ? 'Worn today'
          : (featured ? 'Wear this' : 'Wear this instead'),
      filled: featured,
      loading: logging,
      // Worn outfits can be re-logged (idempotent server-side), but disable
      // while any action on this card is in flight.
      onPressed: _busy ? null : onLogWorn,
    );
  }

  static String _items(int n) => n == 1 ? '1 item' : '$n items';
  static String _pieces(int n) => n == 1 ? '1 piece' : '$n pieces';
}

/// Translucent pill floating on the hero image.
class _ImagePill extends StatelessWidget {
  final Widget child;
  final Color? color;
  const _ImagePill({required this.child, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? AppColors.ivory.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(color: Color(0x142A1810), blurRadius: 4, offset: Offset(0, 1)),
        ],
      ),
      child: child,
    );
  }
}

class _MatchPill extends StatelessWidget {
  final int score;
  const _MatchPill({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.sageDim.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$score% match',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.sage,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

/// The stylist's one-line "why"; tapping opens the full reasoning.
class _ReasonRow extends StatelessWidget {
  final String reasoning;
  final VoidCallback? onTap;
  const _ReasonRow({required this.reasoning, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryDim,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.auto_awesome_outlined,
                    size: 15, color: AppColors.espressoDark),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  reasoning,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        height: 1.55,
                      ),
                ),
              ),
              if (onTap != null)
                const Icon(Icons.chevron_right,
                    size: 16, color: AppColors.taupe),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemChip extends StatelessWidget {
  final String label;
  const _ItemChip(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.ink,
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0,
            ),
      ),
    );
  }
}

/// Full-width wear CTA: espresso gradient when [filled], tonal otherwise.
class _PrimaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;
  final VoidCallback? onPressed;

  const _PrimaryAction({
    required this.icon,
    required this.label,
    this.filled = true,
    this.loading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    final fg = filled ? AppColors.white : AppColors.espressoDark;
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      color: filled ? null : AppColors.ivoryWarm,
      gradient: filled
          ? LinearGradient(
              colors: disabled
                  ? const [AppColors.taupeSoft, AppColors.taupeSoft]
                  : const [Color(0xFF7B5238), AppColors.espresso],
            )
          : null,
      boxShadow: filled && !disabled ? todayCardShadow : null,
    );
    return DecoratedBox(
      decoration: decoration,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 48,
            child: Center(
              child: loading
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(fg),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 18, color: fg),
                        const SizedBox(width: 8),
                        Text(
                          label,
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(color: fg),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _SecondaryAction({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fg = onPressed == null ? AppColors.taupe : AppColors.ink;
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: fg,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0,
                        ),
                  ),
                ),
              ],
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
      color: AppColors.ivory.withValues(alpha: 0.9),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            filled ? Icons.favorite : Icons.favorite_border,
            color: AppColors.espressoDark,
            size: 18,
          ),
        ),
      ),
    );
  }
}
