import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/app_bottom_sheet.dart';
import '../../../shared/widgets/garment_placeholder.dart';
import '../models/outfit.dart';

/// "What feels off" — the reasons a user can give (up to 3).
enum ChangeReason {
  tooFormal('Too formal'),
  tooCasual('Too casual'),
  tooWarm('Too warm'),
  tooCold('Too cold'),
  notMyColours('Not my colours'),
  woreRecently('Wore it recently'),
  notMyStyle('Not my style'),
  other('Other');

  const ChangeReason(this.label);
  final String label;
}

/// What the Change it sheet hands back.
sealed class ChangeOutfitResult {
  const ChangeOutfitResult();
}

/// "Regenerate: show me something new" — a fresh look, no constraints.
class ChangeRegenerate extends ChangeOutfitResult {
  const ChangeRegenerate();
}

/// "Update this outfit" — restyle around the feedback, keeping the locked
/// pieces. (Needs the constrained-regenerate endpoint, BACKEND_CHANGES 1.0.)
class ChangeUpdate extends ChangeOutfitResult {
  final Set<ChangeReason> reasons;

  /// The "Other" text, when Other is picked.
  final String otherText;

  /// Item ids to keep ("Keep these pieces").
  final Set<String> keepItemIds;

  /// "Not for me, do not show this again".
  final bool notForMe;

  const ChangeUpdate({
    required this.reasons,
    required this.otherText,
    required this.keepItemIds,
    required this.notForMe,
  });
}

/// Change it (Stitch `change_outfit_what_would_you_change`), on the shared
/// [AppBottomSheet] at the default height: what feels off (up to 3 reasons, "Other"
/// opens a note), pieces to keep, "Not for me", then Update this outfit or
/// Regenerate. Returns the choice; the caller acts on it.
class ChangeOutfitSheet extends StatefulWidget {
  final Outfit outfit;
  const ChangeOutfitSheet({super.key, required this.outfit});

  static const maxReasons = 3;
  static const otherMax = 140;

  static Future<ChangeOutfitResult?> show(
    BuildContext context,
    Outfit outfit,
  ) => AppBottomSheet.show<ChangeOutfitResult>(
    context,
    builder: (_) => ChangeOutfitSheet(outfit: outfit),
  );

  @override
  State<ChangeOutfitSheet> createState() => _ChangeOutfitSheetState();
}

class _ChangeOutfitSheetState extends State<ChangeOutfitSheet> {
  final Set<ChangeReason> _reasons = {};
  final Set<String> _keep = {};
  bool _notForMe = false;
  late final TextEditingController _other;

  @override
  void initState() {
    super.initState();
    _other = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _other.dispose();
    super.dispose();
  }

  bool get _full => _reasons.length >= ChangeOutfitSheet.maxReasons;
  bool get _canUpdate => _reasons.isNotEmpty || _notForMe;

  void _toggleReason(ChangeReason r) {
    setState(() {
      if (!_reasons.remove(r) && !_full) _reasons.add(r);
    });
  }

  void _update() {
    Navigator.of(context).pop(
      ChangeUpdate(
        reasons: {..._reasons},
        otherText: _reasons.contains(ChangeReason.other)
            ? _other.text.trim()
            : '',
        keepItemIds: {..._keep},
        notForMe: _notForMe,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppBottomSheet(
      title: 'What would you change?',
      actions: _Footer(
        canUpdate: _canUpdate,
        onUpdate: _update,
        onRegenerate: () => Navigator.of(context).pop(const ChangeRegenerate()),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Tell us what feels off and we will fix it.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
          const SizedBox(height: 24),
          // ─── What feels off ───
          Row(
            children: [
              Expanded(
                child: Text(
                  'What feels off',
                  style: text.titleSmall?.copyWith(
                    fontSize: 15,
                    color: AppColors.espressoDeep,
                  ),
                ),
              ),
              Text(
                _reasons.isEmpty
                    ? 'Pick up to ${ChangeOutfitSheet.maxReasons}'
                    : '${_reasons.length} of ${ChangeOutfitSheet.maxReasons}',
                style: text.bodySmall?.copyWith(color: AppColors.taupe),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in ChangeReason.values)
                _ReasonChip(
                  label: r.label,
                  selected: _reasons.contains(r),
                  // Once 3 are picked, the rest wait until one is unpicked.
                  enabled: _reasons.contains(r) || !_full,
                  onTap: () => _toggleReason(r),
                ),
            ],
          ),
          if (_reasons.contains(ChangeReason.other)) ...[
            const SizedBox(height: 12),
            _OtherField(controller: _other),
          ],
          const SizedBox(height: 28),
          // ─── Keep these pieces ───
          Text(
            'Keep these pieces',
            style: text.titleSmall?.copyWith(
              fontSize: 15,
              color: AppColors.espressoDeep,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Locked pieces stay, we change the rest.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 12),
          _PieceGrid(
            items: widget.outfit.items,
            keep: _keep,
            onToggle: (id) => setState(() {
              if (!_keep.remove(id)) _keep.add(id);
            }),
          ),
          const SizedBox(height: 24),
          _NotForMeCard(
            selected: _notForMe,
            onTap: () => setState(() => _notForMe = !_notForMe),
          ),
        ],
      ),
    );
  }
}

// ─── Reasons ────────────────────────────────────────────────────────────

class _ReasonChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  const _ReasonChip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final fg = selected
        ? AppColors.white
        : (enabled ? AppColors.espressoDeep : AppColors.taupeSoft);
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: Material(
        color: selected ? AppColors.espresso : AppColors.ivoryWarm,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selected) ...[
                  Icon(Icons.check, size: 16, color: fg),
                  const SizedBox(width: 6),
                ],
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w500,
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

class _OtherField extends StatelessWidget {
  final TextEditingController controller;
  const _OtherField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        TextField(
          controller: controller,
          autofocus: true,
          maxLength: ChangeOutfitSheet.otherMax,
          minLines: 3,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: text.bodyMedium?.copyWith(color: AppColors.espressoDeep),
          decoration: InputDecoration(
            hintText: 'Tell us what you need',
            hintStyle: text.bodyMedium?.copyWith(color: AppColors.taupe),
            counterText: '', // shown below instead
            filled: true,
            fillColor: AppColors.ivory,
            contentPadding: const EdgeInsets.all(12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.sand),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.espresso),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${controller.text.length} / ${ChangeOutfitSheet.otherMax}',
          style: text.bodySmall?.copyWith(color: AppColors.taupe),
        ),
      ],
    );
  }
}

// ─── Keep these pieces ──────────────────────────────────────────────────

/// Four to a row, like the mock; more pieces wrap onto the next row.
class _PieceGrid extends StatelessWidget {
  final List<OutfitItem> items;
  final Set<String> keep;
  final ValueChanged<String> onToggle;
  const _PieceGrid({
    required this.items,
    required this.keep,
    required this.onToggle,
  });

  static const _perRow = 4;
  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var r = 0; r < items.length; r += _perRow) ...[
          if (r > 0) const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < _perRow; c++) ...[
                if (c > 0) const SizedBox(width: _gap),
                Expanded(
                  child: r + c < items.length
                      ? _PieceTile(
                          item: items[r + c],
                          kept: keep.contains(items[r + c].itemId),
                          onTap: () => onToggle(items[r + c].itemId),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _PieceTile extends StatelessWidget {
  final OutfitItem item;
  final bool kept;
  final VoidCallback onTap;
  const _PieceTile({
    required this.item,
    required this.kept,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final placeholder = GarmentPlaceholder(
      category: item.category,
      color: garmentColorFromName(item.colorName),
    );
    final url = item.primaryImageUrl;
    return Semantics(
      button: true,
      selected: kept,
      label: '${item.name}, ${kept ? 'kept' : 'can change'}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.ivoryDim,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: kept ? AppColors.espresso : AppColors.sand,
                    width: kept ? 2 : 1,
                  ),
                ),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: url == null || url.isEmpty
                          ? placeholder
                          : CachedNetworkImage(
                              imageUrl: url,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => placeholder,
                            ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: kept ? const _KeepPill() : const _OpenLock(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: kept ? AppColors.espressoDeep : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KeepPill extends StatelessWidget {
  const _KeepPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.espresso,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock, size: 11, color: AppColors.white),
          const SizedBox(width: 2),
          Text(
            'Keep',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 9,
              letterSpacing: 0,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenLock extends StatelessWidget {
  const _OpenLock();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_open, size: 13, color: AppColors.taupe),
    );
  }
}

// ─── Not for me ─────────────────────────────────────────────────────────

class _NotForMeCard extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _NotForMeCard({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.ivoryDim,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.espresso : AppColors.sand,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.thumb_down_outlined,
                    size: 20,
                    color: AppColors.espresso,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Not for me, do not show this again',
                        style: text.titleSmall?.copyWith(
                          color: AppColors.espressoDeep,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'We will never suggest this outfit combination again',
                        style: text.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.espresso : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.espresso : AppColors.taupe,
                      ),
                    ),
                    child: selected
                        ? Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                        : null,
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

// ─── Footer ─────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final bool canUpdate;
  final VoidCallback onUpdate;
  final VoidCallback onRegenerate;
  const _Footer({
    required this.canUpdate,
    required this.onUpdate,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: canUpdate
                  ? const [Color(0xFF7B5238), AppColors.espresso]
                  : const [AppColors.taupeSoft, AppColors.taupeSoft],
            ),
            boxShadow: canUpdate
                ? const [
                    BoxShadow(
                      color: Color(0x266B4530),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: canUpdate ? onUpdate : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 56,
                child: Center(
                  child: Text(
                    'Update this outfit',
                    style: text.titleMedium?.copyWith(color: AppColors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: onRegenerate,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.espresso,
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.cached, size: 18),
          label: Text(
            'Regenerate: show me something new',
            style: text.labelLarge?.copyWith(color: AppColors.espresso),
          ),
        ),
        Text(
          'Uses 1 of your 10 ideas this week.',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(color: AppColors.taupe),
        ),
      ],
    );
  }
}
