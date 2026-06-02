import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../image_pick.dart';
import '../models/scan_detection.dart';
import '../models/wardrobe_mutations.dart';
import '../wardrobe_controller.dart';
import '../wardrobe_service.dart';

enum _ScanStatus { pending, scanning, ok, error }

/// One picked image plus the result of its individual scan. The whole batch is
/// held in memory here; each image is sent to the backend on its own.
class _ScanSlot {
  _ScanSlot(this.image);

  final PickedImage image;
  _ScanStatus status = _ScanStatus.pending;
  ScanDetection? detection;
  bool suggestManualEntry = false;
  bool selected = false;
  String? errorMessage;

  bool get isError => status == _ScanStatus.error;
  bool get isDone => status == _ScanStatus.ok;
}

/// Batch add: pick up to [_maxBatch] photos, then scan them **one at a time**
/// via `POST /wardrobe/scan-item` (single-image AI detection). Each scan is its
/// own short request fired sequentially in the background, so the UI fills in
/// per-tile as results land and a slow vision call on one photo never stalls
/// the others or trips the 30s client timeout (the old single batch request
/// did). Review the per-image results → create the selected ones.
class BatchUploadScreen extends ConsumerStatefulWidget {
  static const path = 'batch-upload';
  static const name = 'wardrobe_batch_upload';

  const BatchUploadScreen({super.key});

  @override
  ConsumerState<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends ConsumerState<BatchUploadScreen> {
  static const _maxBatch = 12; // backend MAX_BATCH_SIZE

  final List<_ScanSlot> _slots = [];
  bool _scanning = false;
  bool _creating = false;

  int get _scannedCount =>
      _slots.where((s) => s.status != _ScanStatus.pending && s.status != _ScanStatus.scanning).length;

  int get _selectedCount => _slots.where((s) => s.isDone && s.selected).length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickAndScan());
  }

  Future<void> _pickAndScan() async {
    final picked = await pickWardrobeImages();
    if (picked.isEmpty || !mounted) return;
    if (picked.length > _maxBatch) {
      picked.removeRange(_maxBatch, picked.length);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the first 12 photos were used.')),
      );
    }

    // Hold every image in app state up front and render the grid immediately;
    // the scan loop below fills each tile in as its result returns.
    final start = _slots.length;
    setState(() {
      _slots.addAll(picked.map(_ScanSlot.new));
      _scanning = true;
    });

    await _scanFrom(start);

    if (mounted) setState(() => _scanning = false);
  }

  /// Sequentially scans slots [from]..end — one request at a time so we never
  /// overload the backend or block the UI. State updates after every result.
  Future<void> _scanFrom(int from) async {
    final service = ref.read(wardrobeServiceProvider);
    for (var i = from; i < _slots.length; i++) {
      if (!mounted) return;
      final slot = _slots[i];
      setState(() => slot.status = _ScanStatus.scanning);
      try {
        final result = await service.scanItem(slot.image);
        if (!mounted) return;
        setState(() {
          slot
            ..status = _ScanStatus.ok
            ..detection = result.detection
            ..suggestManualEntry = result.suggestManualEntry
            ..selected = true; // pre-select everything we could detect
        });
      } on ApiException catch (e) {
        if (!mounted) return;
        setState(() {
          slot
            ..status = _ScanStatus.error
            ..errorMessage = e.code == 'low_confidence'
                ? "Couldn't identify this item — add it manually."
                : e.message
            ..selected = false;
        });
      }
    }
  }

  Future<void> _addSelected() async {
    if (_selectedCount == 0) return;
    setState(() => _creating = true);

    final entries = <({WardrobeItemInput input, PickedImage? image})>[];
    for (final slot in _slots) {
      if (!slot.isDone || !slot.selected || slot.detection == null) continue;
      final d = slot.detection!;
      entries.add((
        input: WardrobeItemInput(
          name: d.suggestedName,
          category: d.category,
          colorName: d.color,
          pattern: d.pattern,
          formality: d.formality,
        ),
        image: slot.image,
      ));
    }

    final outcome =
        await ref.read(wardrobeControllerProvider.notifier).createBatch(entries);
    ref.invalidate(wardrobeCapacityProvider);
    if (!mounted) return;
    setState(() => _creating = false);

    if (outcome.limitReached) {
      _showLimitDialog(outcome.created);
      return;
    }
    if (outcome.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added ${outcome.created}, but some failed: ${outcome.error!.message}',
          ),
        ),
      );
    }
    context.pop();
  }

  void _showLimitDialog(int created) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wardrobe full'),
        content: Text(
          'Added $created before hitting the free-tier 30-item limit. '
          'Upgrade to Drape Pro for unlimited storage.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (mounted) context.pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _toggle(_ScanSlot slot) {
    if (!slot.isDone) return;
    setState(() => slot.selected = !slot.selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            _ProgressLabel(
              scanning: _scanning,
              scanned: _scannedCount,
              total: _slots.length,
              selected: _selectedCount,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
            if (_slots.isNotEmpty)
              _BottomBar(
                count: _selectedCount,
                creating: _creating,
                scanning: _scanning,
                onAddMore: _pickAndScan,
                onContinue: _selectedCount == 0 ? null : _addSelected,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_slots.isEmpty) {
      return _EmptyPrompt(onPick: _pickAndScan);
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _slots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) {
        final slot = _slots[i];
        return _ScanTile(slot: slot, onTap: () => _toggle(slot));
      },
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              'Add to Wardrobe',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _ProgressLabel extends StatelessWidget {
  final bool scanning;
  final int scanned;
  final int total;
  final int selected;
  const _ProgressLabel({
    required this.scanning,
    required this.scanned,
    required this.total,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              scanning ? 'SCANNING ASSETS' : 'REVIEW & ADD',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.taupe,
                    letterSpacing: 1.4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          if (total > 0)
            Text(
              scanning ? '$scanned of $total scanned' : '$selected of $total selected',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.espresso,
                    fontWeight: FontWeight.w700,
                  ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPrompt extends StatelessWidget {
  final VoidCallback onPick;
  const _EmptyPrompt({required this.onPick});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.add_a_photo_outlined,
                color: AppColors.taupeSoft, size: 48),
            const SizedBox(height: 16),
            Text(
              'Pick up to 12 photos to add at once.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton(onPressed: onPick, child: const Text('Choose Photos')),
          ],
        ),
      ),
    );
  }
}

class _ScanTile extends StatelessWidget {
  final _ScanSlot slot;
  final VoidCallback onTap;

  const _ScanTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final Uint8List bytes = slot.image.bytes;
    final selected = slot.isDone && slot.selected;
    final label = switch (slot.status) {
      _ScanStatus.pending => 'QUEUED',
      _ScanStatus.scanning => 'SCANNING…',
      _ScanStatus.ok => slot.detection!.category.toUpperCase(),
      _ScanStatus.error => 'FAILED',
    };
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.ivoryWarm,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.espresso : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(bytes, fit: BoxFit.cover),
            if (slot.status != _ScanStatus.ok)
              Container(color: AppColors.black.withValues(alpha: 0.35)),
            Positioned(
              top: 6,
              right: 6,
              child: _StatusBadge(slot: slot, selected: selected),
            ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.espresso.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.white,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
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

class _StatusBadge extends StatelessWidget {
  final _ScanSlot slot;
  final bool selected;
  const _StatusBadge({required this.slot, required this.selected});

  @override
  Widget build(BuildContext context) {
    if (slot.status == _ScanStatus.scanning ||
        slot.status == _ScanStatus.pending) {
      return Container(
        width: 22,
        height: 22,
        decoration: const BoxDecoration(
            color: AppColors.taupe, shape: BoxShape.circle),
        padding: const EdgeInsets.all(4),
        child: slot.status == _ScanStatus.scanning
            ? const CircularProgressIndicator(
                strokeWidth: 2, color: AppColors.white)
            : const Icon(Icons.schedule, color: AppColors.white, size: 13),
      );
    }

    late final Color color;
    late final IconData icon;
    if (slot.isError) {
      color = AppColors.error;
      icon = Icons.close;
    } else if (!selected) {
      color = AppColors.taupe;
      icon = Icons.circle_outlined;
    } else if (slot.suggestManualEntry) {
      color = const Color(0xFFC8901C);
      icon = Icons.priority_high;
    } else {
      color = AppColors.sage;
      icon = Icons.check;
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Icon(icon, color: AppColors.white, size: 13),
    );
  }
}

class _BottomBar extends StatelessWidget {
  final int count;
  final bool creating;
  final bool scanning;
  final VoidCallback onAddMore;
  final VoidCallback? onContinue;

  const _BottomBar({
    required this.count,
    required this.creating,
    required this.scanning,
    required this.onAddMore,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final busy = creating || scanning;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        child: Row(
          children: [
            Material(
              color: AppColors.tanFixed,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: busy ? null : onAddMore,
                customBorder: const CircleBorder(),
                child: const SizedBox(
                  width: 52,
                  height: 52,
                  child: Icon(Icons.add_a_photo_outlined,
                      color: AppColors.espresso, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Material(
                color: onContinue == null ? AppColors.taupe : AppColors.espresso,
                borderRadius: BorderRadius.circular(14),
                child: InkWell(
                  onTap: creating ? null : onContinue,
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 52,
                    child: Center(
                      child: Text(
                        creating
                            ? 'Adding…'
                            : scanning
                                ? 'Scanning…'
                                : count == 0
                                    ? 'Select items to add'
                                    : 'Add $count ${count == 1 ? 'item' : 'items'}',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
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
