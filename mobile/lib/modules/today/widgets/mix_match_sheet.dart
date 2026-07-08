import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../../wardrobe/models/wardrobe_item.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../models/outfit.dart';
import '../today_controller.dart';

/// All wardrobe items, for picking a swap-in piece. AutoDispose so it refetches
/// each time the sheet opens (the wardrobe may have changed).
final _wardrobeItemsProvider = FutureProvider.autoDispose<List<WardrobeItem>>(
  (ref) async => (await ref.read(wardrobeServiceProvider).getItems(limit: 200)).items,
);

/// Mix & Match: pick one piece in the outfit to swap out, then a replacement of
/// the same category from the wardrobe → `POST /outfits/{id}/mix-and-match`.
class MixMatchSheet extends ConsumerStatefulWidget {
  final Outfit outfit;
  const MixMatchSheet({super.key, required this.outfit});

  static Future<void> show(BuildContext context, Outfit outfit) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.espressoDeep.withValues(alpha: 0.4),
      builder: (_) => MixMatchSheet(outfit: outfit),
    );
  }

  @override
  ConsumerState<MixMatchSheet> createState() => _MixMatchSheetState();
}

class _MixMatchSheetState extends ConsumerState<MixMatchSheet> {
  String? _oldItemId;
  String? _newItemId;
  bool _applying = false;

  @override
  void initState() {
    super.initState();
    // Single choke point for both entry paths (quick action + outfit card).
    ref.read(analyticsProvider).capture(
      AnalyticsEvents.mixAndMatchOpened,
      {'occasion': widget.outfit.occasion},
    );
  }

  OutfitItem? get _oldItem =>
      widget.outfit.items.where((i) => i.itemId == _oldItemId).firstOrNull;

  Future<void> _apply() async {
    if (_oldItemId == null || _newItemId == null) return;
    setState(() => _applying = true);
    try {
      await ref.read(todayControllerProvider.notifier).mixAndMatch(
        widget.outfit.id,
        [(oldItemId: _oldItemId!, newItemId: _newItemId!)],
      );
      ref
          .read(analyticsProvider)
          .capture(AnalyticsEvents.outfitItemSwapped, {
        'category': _oldItem?.category,
      });
      if (!mounted) return;
      Navigator.of(context).pop();
      showDrapeToast(context, 'Swapped — match score updated.');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _applying = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final outfitItemIds = widget.outfit.items.map((i) => i.itemId).toSet();
    final wardrobeAsync = ref.watch(_wardrobeItemsProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.sand,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mix & Match',
                        style: Theme.of(context).textTheme.titleLarge),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.taglineGrey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                children: [
                  _SectionLabel(
                      _oldItemId == null ? 'Tap a piece to swap out' : 'Swapping out'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 104,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: widget.outfit.items.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (_, i) {
                        final it = widget.outfit.items[i];
                        return _Tile(
                          imageUrl: it.primaryImageUrl,
                          label: it.name,
                          category: it.category,
                          color: garmentColorFromName(it.colorName),
                          selected: it.itemId == _oldItemId,
                          onTap: () => setState(() {
                            _oldItemId = it.itemId == _oldItemId ? null : it.itemId;
                            _newItemId = null; // category changed → reset pick
                          }),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_oldItem != null) ...[
                    _SectionLabel('Swap in a ${_oldItem!.category}'),
                    const SizedBox(height: 10),
                    wardrobeAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (_, _) => const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text("Couldn't load your wardrobe."),
                      ),
                      data: (items) {
                        final candidates = items
                            .where((w) =>
                                w.category == _oldItem!.category &&
                                !outfitItemIds.contains(w.id))
                            .toList();
                        if (candidates.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              'No other ${_oldItem!.category} in your wardrobe yet — add one to swap.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          );
                        }
                        return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final w in candidates)
                              _Tile(
                                imageUrl: w.displayImageUrl,
                                label: w.name,
                                category: w.category,
                                color: garmentColorFromHex(w.colorHex),
                                selected: w.id == _newItemId,
                                onTap: () =>
                                    setState(() => _newItemId = w.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
            _ActionBar(
              applying: _applying,
              canApply: _oldItemId != null && _newItemId != null && !_applying,
              onDiscard: () => Navigator.of(context).pop(),
              onApply: _apply,
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.taupe,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String? imageUrl;
  final String label;
  final String category;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _Tile({
    required this.imageUrl,
    required this.label,
    required this.category,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.ivoryDim,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected ? AppColors.espresso : AppColors.taupeSoft,
                  width: selected ? 2 : 1,
                ),
              ),
              child: (imageUrl != null && imageUrl!.isNotEmpty)
                  ? Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          GarmentPlaceholder(category: category, color: color),
                    )
                  : GarmentPlaceholder(category: category, color: color),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.espresso : AppColors.ink,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  final bool applying;
  final bool canApply;
  final VoidCallback onDiscard;
  final VoidCallback onApply;
  const _ActionBar({
    required this.applying,
    required this.canApply,
    required this.onDiscard,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          border: Border(top: BorderSide(color: AppColors.taupeSoft)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Expanded(child: _SheetButton.outlined('Discard', applying ? null : onDiscard)),
            const SizedBox(width: 12),
            Expanded(
              child: _SheetButton.filled(
                applying ? 'Swapping…' : 'Apply Swap',
                canApply ? onApply : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;
  const _SheetButton.outlined(this.label, this.onPressed) : filled = false;
  const _SheetButton.filled(this.label, this.onPressed) : filled = true;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Material(
      color: filled
          ? (enabled ? AppColors.espresso : AppColors.taupe)
          : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: filled
            ? BorderSide.none
            : const BorderSide(color: AppColors.espresso, width: 2),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: filled ? AppColors.white : AppColors.espresso,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
