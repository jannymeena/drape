import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../../wardrobe/models/wardrobe_item.dart';
import '../../wardrobe/screens/wardrobe_screen.dart';
import '../../wardrobe/wardrobe_service.dart';
import '../day_plans_controller.dart';
import '../models/day_plan.dart';
import '../models/outfit.dart';
import '../today_controller.dart';
import 'dashed_outline.dart';
import 'plan_day_sheet.dart';
import 'weather_chip.dart';

/// All wardrobe items, for picking swap-ins. AutoDispose so it refetches each
/// time the sheet opens (the wardrobe may have changed).
final _wardrobeItemsProvider = FutureProvider.autoDispose<List<WardrobeItem>>(
  (ref) async =>
      (await ref.read(wardrobeServiceProvider).getItems(limit: 200)).items,
);

/// The five slots of the Mix & match tabs, by garment category.
enum MixSlot {
  layer('Layer', {'outerwear'}),
  top('Top', {'tops', 'dresses'}),
  bottom('Bottom', {'bottoms'}),
  shoes('Shoes', {'shoes'}),
  extra('Extra', {'accessories', 'bags', 'jewelry'});

  const MixSlot(this.label, this.categories);
  final String label;
  final Set<String> categories;

  static MixSlot? of(String category) {
    for (final s in values) {
      if (s.categories.contains(category.toLowerCase())) return s;
    }
    return null;
  }
}

/// A piece shown in the sheet — from the outfit or from the wardrobe.
class _Piece {
  final String id;
  final String name;
  final String category;
  final String? imageUrl;
  final Color? color;
  final String? formality;

  const _Piece({
    required this.id,
    required this.name,
    required this.category,
    this.imageUrl,
    this.color,
    this.formality,
  });

  factory _Piece.fromOutfitItem(OutfitItem i) => _Piece(
    id: i.itemId,
    name: i.name,
    category: i.category,
    imageUrl: i.primaryImageUrl,
    color: garmentColorFromName(i.colorName),
    formality: i.formality,
  );

  factory _Piece.fromWardrobe(WardrobeItem w) => _Piece(
    id: w.id,
    name: w.name,
    category: w.category,
    imageUrl: w.displayImageUrl,
    color: garmentColorFromHex(w.colorHex) ?? garmentColorFromName(w.colorName),
    formality: w.formality,
  );
}

/// Mix & match (Stitch `mix_match_zoura`): a live preview of the look, a
/// fit-check line, Layer / Top / Bottom / Shoes / Extra tabs and a grid of
/// wardrobe pieces for the selected slot. Picks only change the preview;
/// **Save** / **Wear this** send every swap in one
/// `POST /outfits/{id}/mix-and-match` (one mix of the weekly allowance),
/// then favourite / log the look. Reset and close discard.
class MixMatchSheet extends ConsumerStatefulWidget {
  final Outfit outfit;
  const MixMatchSheet({super.key, required this.outfit});

  static Future<void> show(BuildContext context, Outfit outfit) {
    return AppBottomSheet.show<void>(
      context,
      builder: (_) => MixMatchSheet(outfit: outfit),
    );
  }

  @override
  ConsumerState<MixMatchSheet> createState() => _MixMatchSheetState();
}

class _MixMatchSheetState extends ConsumerState<MixMatchSheet> {
  /// The outfit's piece in each slot (first one, when a slot has several).
  late final Map<MixSlot, _Piece> _original;

  /// The current pick per slot (starts as [_original]).
  late Map<MixSlot, _Piece> _picks;
  late MixSlot _slot;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _original = {};
    for (final i in widget.outfit.items) {
      final slot = MixSlot.of(i.category);
      if (slot != null) {
        _original.putIfAbsent(slot, () => _Piece.fromOutfitItem(i));
      }
    }
    _picks = {..._original};
    _slot = MixSlot.values.firstWhere(
      _original.containsKey,
      orElse: () => MixSlot.layer,
    );
    // Single choke point for every entry path (outfit card, Favourites…).
    ref.read(analyticsProvider).capture(AnalyticsEvents.mixAndMatchOpened, {
      'occasion': widget.outfit.occasion,
    });
  }

  List<({String oldItemId, String newItemId})> get _swaps => [
    for (final e in _original.entries)
      if (_picks[e.key] != null && _picks[e.key]!.id != e.value.id)
        (oldItemId: e.value.id, newItemId: _picks[e.key]!.id),
  ];

  bool get _changed => _swaps.isNotEmpty;

  /// The outfit's dress level (most common item formality), raw literal.
  String? get _dressLevel {
    final counts = <String, int>{};
    for (final i in widget.outfit.items) {
      final f = i.formality;
      if (f != null) counts[f] = (counts[f] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  void _toast(String message, {IconData icon = Icons.schedule}) =>
      showDrapeToast(
        context,
        message,
        icon: icon,
        background: AppColors.espressoDeep,
      );

  void _pick(_Piece piece) {
    if (!_original.containsKey(_slot)) {
      _toast('Adding a ${_slot.label.toLowerCase()} piece is coming soon.');
      return;
    }
    setState(() => _picks[_slot] = piece);
  }

  void _pickNone() {
    if (!_original.containsKey(_slot)) return; // already none
    _toast('Removing a piece is coming soon.');
  }

  /// Sends the swaps (if any). Returns false when it failed (already shown).
  Future<bool> _applySwaps() async {
    final swaps = _swaps;
    if (swaps.isEmpty) return true;
    try {
      await ref
          .read(todayControllerProvider.notifier)
          .mixAndMatch(widget.outfit.id, swaps);
      final analytics = ref.read(analyticsProvider);
      for (final e in _original.entries) {
        if (_picks[e.key]?.id != e.value.id) {
          analytics.capture(AnalyticsEvents.outfitItemSwapped, {
            'category': e.value.category,
          });
        }
      }
      return true;
    } on ApiException catch (e) {
      _fail(e.message);
      return false;
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() => _busy = false);
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

  Future<void> _save() async {
    setState(() => _busy = true);
    if (!await _applySwaps()) return;
    try {
      if (!widget.outfit.isFavorite) {
        await ref
            .read(todayControllerProvider.notifier)
            .toggleFavorite(widget.outfit.id);
      }
    } on ApiException catch (e) {
      _fail(e.message);
      return;
    }
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Saved to favourites'),
        backgroundColor: AppColors.espressoDeep,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _wear() async {
    setState(() => _busy = true);
    if (!await _applySwaps()) return;
    try {
      final result = await ref
          .read(todayControllerProvider.notifier)
          .logWorn(widget.outfit.id);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(result.toast.message),
          backgroundColor: AppColors.espresso,
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: result.toast.durationMs),
        ),
      );
    } on ApiException catch (e) {
      _fail(e.message);
    }
  }

  void _addMore() {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.goNamed(WardrobeScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = ref.watch(_wardrobeItemsProvider);
    // The shared sheet: grabber, fixed title, one scrolling body (context,
    // preview, fit line, tabs, grid), Save / Wear this in the footer.
    return AppBottomSheet(
      title: 'Mix & match',
      heightFactor: 0.6,
      actions: _BottomBar(
        busy: _busy,
        onSave: _busy ? null : _save,
        onWear: _busy ? null : _wear,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _topContent(),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.sand),
          _grid(wardrobe),
        ],
      ),
    );
  }

  // ─── Scrolling top: context, preview, fit line, slot tabs ─────────────

  Widget _topContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ContextChip(
          label: _contextLabel(),
          onEdit: () => PlanDaySheet.open(context, ref, DateTime.now()),
        ),
        const SizedBox(height: 10),
        _Preview(picks: _picks),
        const SizedBox(height: 8),
        _FitLine(fit: _fit()),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (i, s) in MixSlot.values.indexed) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: _SlotTab(
                  slot: s,
                  piece: _picks[s],
                  selected: s == _slot,
                  onTap: () => setState(() => _slot = s),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// "For: Parents' meeting · Smart casual · Rain" — today's plan when there
  /// is one, else the outfit's occasion + dress level; plus today's weather.
  String _contextLabel() {
    final plan = ref.watch(dayPlansProvider)[dayOnly(DateTime.now())];
    final w =
        ref.watch(todayControllerProvider).dashboard?.weather ??
        widget.outfit.weatherContext;
    final level = _dressLevel;
    final parts = <String>[
      if (plan != null) ...[
        plan.note.isEmpty ? plan.occasion.label : plan.note,
        plan.dress.label,
      ] else ...[
        widget.outfit.occasionLabel,
        if (level != null) _labelOf(level),
      ],
      if (w != null && weatherConditionLabel(w.condition) != null)
        weatherConditionLabel(w.condition)!,
    ];
    return 'For: ${parts.join(' · ')}';
  }

  /// Fit check: every picked piece at the outfit's dress level → ok.
  ({bool ok, String message}) _fit() {
    final level = _dressLevel;
    final weather = widget.outfit.weatherContext;
    final c = weather?.condition.toLowerCase() ?? '';
    final weatherWord = c.contains('rain') || c.contains('drizzle')
        ? 'rain'
        : c.contains('snow')
        ? 'snow'
        : (weather != null && weather.feelsLikeC <= 5 ? 'the cold' : null);
    if (level == null) {
      return (ok: true, message: 'Built from your wardrobe');
    }
    final odd = _picks.values
        .where((p) => p.formality != null && p.formality != level)
        .toList();
    if (odd.isEmpty) {
      final phrase = [
        ?weatherWord,
        _labelOf(level).toLowerCase(),
      ].join(' and ');
      return (ok: true, message: 'Works for $phrase');
    }
    return (
      ok: false,
      message:
          '${odd.first.name} is more '
          '${_labelOf(odd.first.formality!).toLowerCase()} than the rest',
    );
  }

  static String _labelOf(String formality) {
    final words = formality.replaceAll('_', ' ');
    return '${words[0].toUpperCase()}${words.substring(1)}';
  }

  // ─── Grid for the selected slot ───────────────────────────────────────

  Widget _grid(AsyncValue<List<WardrobeItem>> wardrobe) {
    final text = Theme.of(context).textTheme;
    final original = _original[_slot];
    final picked = _picks[_slot];
    final level = _dressLevel;

    return switch (wardrobe) {
      AsyncError() => Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          "Couldn't load your wardrobe.",
          textAlign: TextAlign.center,
          style: text.bodyMedium,
        ),
      ),
      AsyncData(:final value) => () {
        final inOutfit = {for (final p in _original.values) p.id};
        final candidates = <_Piece>[
          ?original,
          for (final w in value)
            if (_slot.categories.contains(w.category.toLowerCase()) &&
                !inOutfit.contains(w.id))
              _Piece.fromWardrobe(w),
        ];
        // The current pick first, then best fits, then the rest.
        bool best(_Piece p) =>
            level != null && p.formality == level && p.id != original?.id;
        final ordered = [
          ...candidates.where((p) => p.id == original?.id),
          ...candidates.where((p) => p.id != original?.id && best(p)),
          ...candidates.where((p) => p.id != original?.id && !best(p)),
        ];
        // As in the design. (Each Save / Wear with changes uses one of the
        // free tier's weekly mixes today — BACKEND_CHANGES 1.0.)
        final helper = [
          _slot.label,
          '${candidates.length} ${candidates.length == 1 ? 'option' : 'options'}',
          'Swapping is free',
        ].join(' · ');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 6),
            // Helper line, with Reset at its end (the sheet's title row is
            // text-only, so Reset lives right above the pieces it resets).
            Row(
              children: [
                Expanded(
                  child: Text(
                    helper,
                    style: text.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _changed && !_busy
                      ? () => setState(() => _picks = {..._original})
                      : null,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.inkSoft,
                    minimumSize: const Size(48, 40),
                    padding: const EdgeInsets.only(left: 12),
                  ),
                  child: Text(
                    'Reset',
                    style: text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: _changed ? AppColors.inkSoft : AppColors.taupeSoft,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 116,
              ),
              children: [
                _NoneTile(selected: picked == null, onTap: _pickNone),
                for (final p in ordered)
                  _PieceTile(
                    piece: p,
                    selected: picked?.id == p.id,
                    bestFit:
                        best(p) ||
                        (p.id == original?.id && p.formality == level),
                    onTap: () => _pick(p),
                  ),
                _AddMoreTile(onTap: _addMore),
              ],
            ),
          ],
        );
      }(),
      _ => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.espresso),
        ),
      ),
    };
  }
}

// ─── Pieces ─────────────────────────────────────────────────────────────

class _ContextChip extends StatelessWidget {
  final String label;
  final VoidCallback onEdit;
  const _ContextChip({required this.label, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.calendar_today_outlined,
            size: 16,
            color: AppColors.espresso,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.espressoDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            tooltip: "Edit today's plan",
            icon: const Icon(
              Icons.edit_outlined,
              size: 16,
              color: AppColors.espresso,
            ),
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

/// The live look, laid out like the mock: the layer full height on the
/// left, top over the extra in the middle, bottom over shoes on the right.
/// Empty slots fold away so the rest fill the space.
class _Preview extends StatelessWidget {
  final Map<MixSlot, _Piece> picks;
  const _Preview({required this.picks});

  static const _gap = 8.0;
  static const _smallHeight = 64.0;

  @override
  Widget build(BuildContext context) {
    Widget cell(_Piece p, {double radius = 12}) => DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D2A1810),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox.expand(child: _PieceImage(piece: p)),
      ),
    );

    Widget? stack(_Piece? big, _Piece? small) {
      if (big == null && small == null) return null;
      if (big == null) return cell(small!);
      if (small == null) return cell(big);
      return Column(
        children: [
          Expanded(child: cell(big)),
          const SizedBox(height: _gap),
          SizedBox(height: _smallHeight, child: cell(small)),
        ],
      );
    }

    final layer = picks[MixSlot.layer];
    final columns = [
      if (layer != null) cell(layer, radius: 14),
      ?stack(picks[MixSlot.top], picks[MixSlot.extra]),
      ?stack(picks[MixSlot.bottom], picks[MixSlot.shoes]),
    ];

    return Container(
      height: 180,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.ivoryDim,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A2A1810),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, c) in columns.indexed) ...[
            if (i > 0) const SizedBox(width: _gap),
            Expanded(child: c),
          ],
        ],
      ),
    );
  }
}

class _FitLine extends StatelessWidget {
  final ({bool ok, String message}) fit;
  const _FitLine({required this.fit});

  static const _warn = Color(0xFFC24040);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          fit.ok ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          size: 16,
          color: fit.ok ? AppColors.sage : _warn,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            fit.message,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: fit.ok ? AppColors.ink : _warn,
              fontWeight: fit.ok ? FontWeight.w500 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SlotTab extends StatelessWidget {
  final MixSlot slot;
  final _Piece? piece;
  final bool selected;
  final VoidCallback onTap;
  const _SlotTab({
    required this.slot,
    required this.piece,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: '${slot.label}${piece == null ? ', none' : ', ${piece!.name}'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 72,
          decoration: BoxDecoration(
            color: selected ? AppColors.ivoryDim : AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.sand,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: piece == null
                      ? const ColoredBox(
                          color: AppColors.ivoryWarm,
                          child: Icon(
                            Icons.remove,
                            size: 16,
                            color: AppColors.taupe,
                          ),
                        )
                      : _PieceImage(piece: piece!),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                slot.label,
                maxLines: 1,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected ? AppColors.espressoDeep : AppColors.inkSoft,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PieceImage extends StatelessWidget {
  final _Piece piece;
  const _PieceImage({required this.piece});

  @override
  Widget build(BuildContext context) {
    final placeholder = GarmentPlaceholder(
      category: piece.category,
      color: piece.color,
    );
    final url = piece.imageUrl;
    if (url == null || url.isEmpty) return placeholder;
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      errorWidget: (_, _, _) => placeholder,
    );
  }
}

class _PieceTile extends StatelessWidget {
  final _Piece piece;
  final bool selected;
  final bool bestFit;
  final VoidCallback onTap;
  const _PieceTile({
    required this.piece,
    required this.selected,
    required this.bestFit,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.espresso : AppColors.sand,
              width: selected ? 2 : 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A2A1810),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: ColoredBox(
                        color: AppColors.ivoryDim,
                        child: _PieceImage(piece: piece),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    piece.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: text.bodySmall?.copyWith(
                      color: selected
                          ? AppColors.espressoDeep
                          : AppColors.inkSoft,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (bestFit)
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Best fit',
                      style: text.labelSmall?.copyWith(
                        fontSize: 10,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w700,
                        color: AppColors.espresso,
                      ),
                    ),
                  ),
                ),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: const BoxDecoration(
                      color: AppColors.espresso,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: AppColors.white,
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

class _NoneTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _NoneTile({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'None',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: DashedOutline(
          radius: 16,
          color: selected ? AppColors.espresso : AppColors.taupe,
          fill: AppColors.ivoryDim.withValues(alpha: 0.4),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.sand),
                  ),
                  child: const Icon(
                    Icons.remove,
                    size: 18,
                    color: AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'None',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddMoreTile extends StatelessWidget {
  final VoidCallback onTap;
  const _AddMoreTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add more in Wardrobe',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: DashedOutline(
          radius: 16,
          color: AppColors.taupe,
          fill: AppColors.ivoryDim.withValues(alpha: 0.6),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: const Icon(
                      Icons.add,
                      size: 16,
                      color: AppColors.espresso,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Add more in Wardrobe',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
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

class _BottomBar extends StatelessWidget {
  final bool busy;
  final VoidCallback? onSave;
  final VoidCallback? onWear;
  const _BottomBar({required this.busy, this.onSave, this.onWear});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    // The sheet's footer slot provides the bar, padding and safe area.
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Material(
            color: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.espresso, width: 1.5),
            ),
            child: InkWell(
              onTap: onSave,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 56,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.favorite_border,
                      size: 18,
                      color: AppColors.espresso,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Save',
                      style: text.titleSmall?.copyWith(
                        fontSize: 15,
                        color: AppColors.espresso,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF7B5238), AppColors.espresso],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x406B4530),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: onWear,
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.white,
                            ),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.checkroom,
                                size: 20,
                                color: AppColors.white,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Wear this',
                                style: text.titleSmall?.copyWith(
                                  fontSize: 15,
                                  color: AppColors.white,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
