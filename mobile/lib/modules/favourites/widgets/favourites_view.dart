import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../../../shared/widgets/shimmer_skeleton.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/status_message.dart';
import '../../today/models/outfit.dart';
import '../../today/today_controller.dart';
import '../../today/widgets/outfit_card.dart';
import '../../today/widgets/outfit_image.dart';
import '../../today/widgets/shop_the_look_sheet.dart';
import '../../wardrobe/models/wardrobe_item.dart';
import '../../wardrobe/screens/item_detail_screen.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../favourites_providers.dart';

/// The Favourites tab of My Outfits (Stitch `favourites_zoura`): Outfits /
/// Items with counts, a "We are learning your taste" card, and a two-column
/// grid of saved looks or pieces — heart to un-save (with Undo), "Wear this"
/// on outfits.
class FavouritesView extends ConsumerStatefulWidget {
  const FavouritesView({super.key});

  @override
  ConsumerState<FavouritesView> createState() => _FavouritesViewState();
}

enum _Tab { outfits, items }

class _FavouritesViewState extends ConsumerState<FavouritesView> {
  _Tab _tab = _Tab.outfits;

  static const _gutter = 20.0;

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.espressoDeep,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _undoable(String message, Future<void> Function() undo) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.espressoDeep,
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            textColor: AppColors.white,
            onPressed: () => undo(),
          ),
        ),
      );
  }

  /// Debug sample cards aren't saved anywhere — say so instead of calling
  /// the API with a made-up id.
  bool _isSample(String id) {
    if (!isSampleFavourite(id)) return false;
    showDrapeToast(
      context,
      'Sample card — heart a real outfit or piece to see it here.',
      icon: Icons.info_outline,
      background: AppColors.espressoDeep,
    );
    return true;
  }

  Future<void> _unsaveOutfit(Outfit outfit) async {
    if (_isSample(outfit.id)) return;
    final controller = ref.read(todayControllerProvider.notifier);
    try {
      await controller.toggleFavorite(outfit.id);
      if (!mounted) return;
      _undoable('Removed from favourites', () async {
        try {
          await controller.toggleFavorite(outfit.id);
        } on ApiException catch (e) {
          if (mounted) _showError(e.message);
        }
      });
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _unsaveItem(WardrobeItem item) async {
    if (_isSample(item.id)) return;
    final service = ref.read(wardrobeServiceProvider);
    try {
      await service.toggleFavorite(item.id);
      ref.invalidate(favouriteItemsProvider);
      if (!mounted) return;
      _undoable('Removed from favourites', () async {
        try {
          await service.toggleFavorite(item.id);
          ref.invalidate(favouriteItemsProvider);
        } on ApiException catch (e) {
          if (mounted) _showError(e.message);
        }
      });
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  Future<void> _wear(Outfit outfit) async {
    if (_isSample(outfit.id)) return;
    try {
      final result = await ref
          .read(todayControllerProvider.notifier)
          .logWorn(outfit.id);
      if (!mounted) return;
      showDrapeToast(
        context,
        result.toast.message,
        background: AppColors.espresso,
        duration: Duration(milliseconds: result.toast.durationMs),
      );
    } on ApiException catch (e) {
      if (mounted) _showError(e.message);
    }
  }

  void _whyThis() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.ivory,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final text = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Why am I seeing this?', style: AppTypography.screenTitle),
                const SizedBox(height: 8),
                Text(
                  'It comes from the outfits and pieces you save here — the '
                  'dress level and colours that show up most. Your stylist '
                  'leans on it when picking your daily outfits. Un-save '
                  'anything to change it.',
                  style: text.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final today = ref.watch(todayControllerProvider);
    final outfits = ref.watch(favouriteOutfitsProvider);
    final itemsAsync = ref.watch(favouriteItemsProvider);
    final items = itemsAsync.valueOrNull ?? const <WardrobeItem>[];
    final insight = tasteInsight(outfits: outfits, items: items);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(favouriteItemsProvider);
        await ref.read(todayControllerProvider.notifier).loadFrame();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(_gutter, 0, _gutter, 40),
        children: [
          SegmentedTabs(
            tabs: [
              SegmentedTab('Outfits', count: outfits.length),
              SegmentedTab('Items', count: itemsAsync.valueOrNull?.length),
            ],
            selected: _tab.index,
            onSelect: (i) => setState(() => _tab = _Tab.values[i]),
          ),
          const SizedBox(height: 20),
          if (insight != null) ...[
            _InsightCard(message: insight, onWhy: _whyThis),
            const SizedBox(height: 20),
          ],
          ...switch (_tab) {
            _Tab.outfits => _outfitsTab(today, outfits),
            _Tab.items => _itemsTab(itemsAsync),
          },
        ],
      ),
    );
  }

  List<Widget> _outfitsTab(TodayState today, List<Outfit> outfits) {
    if (!today.hasData && today.frameLoading) return const [_GridSkeleton()];
    if (!today.hasData && today.frameError != null) {
      return [
        StatusMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load your outfits",
          body: today.frameError!.message,
          action: 'Try again',
          onAction: () =>
              ref.read(todayControllerProvider.notifier).loadFrame(),
        ),
      ];
    }
    if (outfits.isEmpty) {
      return const [
        StatusMessage(
          icon: Icons.favorite_border,
          title: 'No saved outfits yet',
          body: 'Tap the heart on any outfit to keep it here.',
        ),
      ];
    }
    return [
      _Grid(
        children: [
          for (final o in outfits)
            _OutfitTile(
              outfit: o,
              logging: today.loggingIds.contains(o.id),
              onUnsave: () => _unsaveOutfit(o),
              onWear: () =>
                  o.shopTheLook ? ShopTheLookSheet.show(context, o) : _wear(o),
            ),
        ],
      ),
    ];
  }

  List<Widget> _itemsTab(AsyncValue<List<WardrobeItem>> async) {
    return switch (async) {
      AsyncData(:final value) when value.isEmpty => const [
        StatusMessage(
          icon: Icons.favorite_border,
          title: 'No saved pieces yet',
          body:
              'Tap the heart on any piece in your wardrobe to keep it '
              'here.',
        ),
      ],
      AsyncData(:final value) => [
        _Grid(
          children: [
            for (final item in value)
              _ItemTile(
                item: item,
                onUnsave: () => _unsaveItem(item),
                onOpen: () {
                  if (_isSample(item.id)) return;
                  context.goNamed(
                    ItemDetailScreen.name,
                    pathParameters: {'id': item.id},
                  );
                },
              ),
          ],
        ),
      ],
      AsyncError(:final error) => [
        StatusMessage(
          icon: Icons.cloud_off_outlined,
          title: "Couldn't load your pieces",
          body: error is ApiException
              ? error.message
              : 'Check your connection and try again.',
          action: 'Try again',
          onAction: () => ref.invalidate(favouriteItemsProvider),
        ),
      ],
      _ => const [_GridSkeleton()],
    };
  }
}

// ─── Taste insight ──────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  final String message;
  final VoidCallback onWhy;
  const _InsightCard({required this.message, required this.onWhy});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.ivoryWarm,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome_outlined,
              size: 20,
              color: AppColors.espressoDark,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We are learning your taste',
                  style: AppTypography.sectionTitle.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 4),
                Text(message, style: text.bodyMedium),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: onWhy,
                  child: Text(
                    'Why am I seeing this?',
                    style: text.bodyMedium?.copyWith(
                      color: AppColors.espressoDark,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.espressoDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Grid + tiles ───────────────────────────────────────────────────────

/// Two columns; each row's tiles share a height so buttons line up.
class _Grid extends StatelessWidget {
  final List<Widget> children;
  const _Grid({required this.children});

  static const gap = 14.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: gap),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: gap),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TileShell extends StatelessWidget {
  final Widget image;
  final String title;
  final String subtitle;
  final VoidCallback onUnsave;
  final VoidCallback? onTap;
  final Widget? button;
  const _TileShell({
    required this.image,
    required this.title,
    required this.subtitle,
    required this.onUnsave,
    this.onTap,
    this.button,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: todayCardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 0.82,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: image,
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: _SavedHeart(onTap: onUnsave),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ],
                ),
              ),
              if (button != null) ...[
                const Spacer(),
                const SizedBox(height: 10),
                button!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedHeart extends StatelessWidget {
  final VoidCallback onTap;
  const _SavedHeart({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Remove from favourites',
      child: Material(
        color: AppColors.espressoDark,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.favorite, size: 18, color: AppColors.white),
          ),
        ),
      ),
    );
  }
}

String _wornLabel(int n) => switch (n) {
  0 => 'Never worn',
  1 => 'Worn 1 time',
  _ => 'Worn $n times',
};

class _OutfitTile extends StatelessWidget {
  final Outfit outfit;
  final bool logging;
  final VoidCallback onUnsave;
  final VoidCallback onWear;
  const _OutfitTile({
    required this.outfit,
    required this.logging,
    required this.onUnsave,
    required this.onWear,
  });

  @override
  Widget build(BuildContext context) {
    final card = OutfitCardData.fromOutfit(outfit);
    return _TileShell(
      // The tile's AspectRatio sizes it; photo if there is one, else collage.
      image: OutfitImage(imageUrl: outfit.imageUrl, cells: card.items),
      title: card.title,
      subtitle: '${card.occasion} · ${_wornLabel(outfit.wornCount)}',
      onUnsave: onUnsave,
      button: _TonalButton(
        label: outfit.shopTheLook
            ? 'Shop the look'
            : (outfit.isLogged ? 'Worn today' : 'Wear this'),
        loading: logging,
        onTap: logging ? null : onWear,
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  final WardrobeItem item;
  final VoidCallback onUnsave;
  final VoidCallback onOpen;
  const _ItemTile({
    required this.item,
    required this.onUnsave,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final placeholder = GarmentPlaceholder(
      category: item.category,
      color: garmentColorFromName(item.colorName),
    );
    final url = item.displayImageUrl;
    return _TileShell(
      image: ColoredBox(
        color: AppColors.ivoryWarm,
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
      title: item.name,
      subtitle: '${item.categoryLabel} · ${_wornLabel(item.wornCount)}',
      onUnsave: onUnsave,
      onTap: onOpen,
    );
  }
}

class _TonalButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  const _TonalButton({required this.label, this.loading = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivoryWarm,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 40,
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.espresso,
                    ),
                  )
                : Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.espressoDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

// ─── Loading / empty / error ────────────────────────────────────────────

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget tile() => Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: todayCardShadow,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 0.82,
            child: ShimmerSkeleton(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
          SizedBox(height: 10),
          ShimmerSkeleton(height: 16),
          SizedBox(height: 6),
          SizedBox(width: 90, child: ShimmerSkeleton(height: 12)),
          SizedBox(height: 10),
          ShimmerSkeleton(
            height: 40,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ],
      ),
    );
    return Column(
      children: [
        for (var r = 0; r < 2; r++) ...[
          if (r > 0) const SizedBox(height: _Grid.gap),
          Row(
            children: [
              Expanded(child: tile()),
              const SizedBox(width: _Grid.gap),
              Expanded(child: tile()),
            ],
          ),
        ],
      ],
    );
  }
}
