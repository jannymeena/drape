import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../image_pick.dart';
import '../models/wardrobe_item.dart';
import '../wardrobe_controller.dart';
import '../wardrobe_service.dart';
import '../widgets/remove_confirmation_modal.dart';
import 'manual_entry_screen.dart';

/// Wardrobe item detail (`GET /wardrobe/items/{id}`). SP2 wires the actions:
/// log-worn, delete, favorite (in the ⋮ menu), and edit. The "appeared in N
/// outfits" section is omitted — there's no backend endpoint that lists the
/// outfits an item belongs to.
class ItemDetailScreen extends ConsumerWidget {
  static const path = 'items/:id';
  static const name = 'wardrobe_item_detail';

  final String itemId;

  const ItemDetailScreen({super.key, required this.itemId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(wardrobeItemProvider(itemId));

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        bottom: false,
        child: item.when(
          loading: () => Column(
            children: [
              _TopBar(onBack: () => context.pop()),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.espresso),
                ),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              _TopBar(onBack: () => context.pop()),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      e is ApiException
                          ? e.message
                          : "We couldn't load this item.",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
            ],
          ),
          data: (item) => Column(
            children: [
              _TopBar(
                onBack: () => context.pop(),
                isFavorite: item.isFavorite,
                onEdit: () => _edit(context, ref),
                onToggleFavorite: () => _toggleFavorite(context, ref),
                onAddPhoto: () => _addPhoto(context, ref),
              ),
              Expanded(child: _Body(item: item, onEdit: () => _edit(context, ref))),
              _BottomActions(
                item: item,
                onLogWorn: () => _logWorn(context, ref),
                onRemove: () => _remove(context, ref, item.name),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref) async {
    await context.pushNamed(
      ManualEntryScreen.name,
      queryParameters: {'id': itemId},
    );
    // The edit screen invalidates the provider on save; this catches any other
    // return path so the detail reflects the latest item.
    ref.invalidate(wardrobeItemProvider(itemId));
  }

  Future<void> _addPhoto(BuildContext context, WidgetRef ref) async {
    final picked = await pickWardrobeImage(context);
    if (picked == null || !context.mounted) return;
    try {
      await ref
          .read(wardrobeControllerProvider.notifier)
          .addImages(itemId, [picked]);
      ref.invalidate(wardrobeItemProvider(itemId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Photo added')));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _toggleFavorite(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(wardrobeControllerProvider.notifier).toggleFavorite(itemId);
      ref.invalidate(wardrobeItemProvider(itemId));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _logWorn(BuildContext context, WidgetRef ref) async {
    try {
      final result =
          await ref.read(wardrobeControllerProvider.notifier).logWorn(itemId);
      ref.invalidate(wardrobeItemProvider(itemId));
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.alreadyLoggedToday
              ? 'Already logged today'
              : 'Logged as worn today'),
        ),
      );
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String name) async {
    final confirmed =
        await RemoveConfirmationModal.show(context, itemName: name);
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(wardrobeControllerProvider.notifier).deleteItem(itemId);
      ref.invalidate(wardrobeCapacityProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Removed from wardrobe')));
      context.pop();
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }
}

class _Body extends StatelessWidget {
  final WardrobeItem item;
  final VoidCallback onEdit;
  const _Body({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (item.brand != null && item.brand!.isNotEmpty) item.brand,
      'Added ${item.addedLabel}',
    ].join(' · ');

    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 16),
      children: [
        _HeroImage(item: item, onEdit: onEdit),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 16),
              _CostPerWearCard(item: item),
              const SizedBox(height: 20),
              _AttributesCard(item: item),
              if (item.description != null && item.description!.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Notes', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 6),
                Text(item.description!,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  final bool isFavorite;
  final VoidCallback? onEdit;
  final VoidCallback? onToggleFavorite;
  final VoidCallback? onAddPhoto;

  const _TopBar({
    required this.onBack,
    this.isFavorite = false,
    this.onEdit,
    this.onToggleFavorite,
    this.onAddPhoto,
  });

  @override
  Widget build(BuildContext context) {
    final hasMenu =
        onEdit != null || onToggleFavorite != null || onAddPhoto != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          const Spacer(),
          if (hasMenu)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.espresso),
              onSelected: (value) {
                if (value == 'edit') onEdit?.call();
                if (value == 'favorite') onToggleFavorite?.call();
                if (value == 'photo') onAddPhoto?.call();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'edit', child: Text('Edit')),
                const PopupMenuItem(value: 'photo', child: Text('Add photo')),
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(
                    isFavorite ? 'Remove from favorites' : 'Add to favorites',
                  ),
                ),
              ],
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HeroImage extends StatelessWidget {
  final WardrobeItem item;
  final VoidCallback onEdit;
  const _HeroImage({required this.item, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final imageUrl = item.displayImageUrl;
    final placeholder = GarmentPlaceholder(
      category: item.category,
      color: garmentColorFromHex(item.colorHex),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            children: [
              Positioned.fill(
                child: imageUrl == null
                    ? placeholder
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => placeholder,
                      ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.espresso,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    item.categoryLabel.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.white,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                right: 12,
                child: GestureDetector(
                  onTap: onEdit,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.edit,
                        color: AppColors.espresso, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostPerWearCard extends StatelessWidget {
  final WardrobeItem item;
  const _CostPerWearCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cpw = item.costPerWear;
    final hasData = cpw != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COST PER WEAR',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.7),
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            hasData ? '\$${cpw.toStringAsFixed(2)}' : '—',
            style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: AppColors.brandText,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            hasData
                ? '${item.wornCount} wears'
                    '${item.purchasePrice != null ? ' · \$${item.purchasePrice!.toStringAsFixed(2)} purchase price' : ''}'
                : 'Add a purchase price and log wears to track cost per wear.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.brandText.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _AttributesCard extends StatelessWidget {
  final WardrobeItem item;
  const _AttributesCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final rows = <_Attribute>[
      _Attribute('Added', item.addedLabel),
      _Attribute('Category', item.categoryLabel),
      if (item.colorName != null) _Attribute('Color', item.colorName!),
      if (item.pattern != null) _Attribute('Pattern', _titleCase(item.pattern!)),
      if (item.material != null) _Attribute('Material', item.material!),
      if (item.formality != null)
        _Attribute('Formality', _titleCase(item.formality!)),
      if (item.season != null && item.season!.isNotEmpty)
        _Attribute('Season', item.season!.map(_titleCase).join(', ')),
      _Attribute('Worn', item.wornCount == 1 ? 'Once' : '${item.wornCount} times'),
      _Attribute('Last worn', item.lastWornLabel ?? 'Never'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.taupeSoft),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++)
            _AttributeRow(
              attribute: rows[i],
              showDivider: i < rows.length - 1,
            ),
        ],
      ),
    );
  }
}

class _Attribute {
  final String label;
  final String value;
  const _Attribute(this.label, this.value);
}

class _AttributeRow extends StatelessWidget {
  final _Attribute attribute;
  final bool showDivider;

  const _AttributeRow({required this.attribute, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: showDivider
              ? BorderSide(color: AppColors.taupeSoft.withValues(alpha: 0.6))
              : BorderSide.none,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              attribute.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.taupe,
                  ),
            ),
          ),
          Text(
            attribute.value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _BottomActions extends StatelessWidget {
  final WardrobeItem item;
  final VoidCallback onLogWorn;
  final VoidCallback onRemove;
  const _BottomActions({
    required this.item,
    required this.onLogWorn,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Column(
          children: [
            Material(
              color: AppColors.espresso,
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                onTap: onLogWorn,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'Log as Worn Today',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: AppColors.ivory,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.error, width: 1.2),
              ),
              child: InkWell(
                onTap: onRemove,
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Center(
                    child: Text(
                      'Remove from Wardrobe',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _titleCase(String s) => s
    .split('_')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
