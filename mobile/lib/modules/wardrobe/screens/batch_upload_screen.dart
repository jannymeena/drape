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

/// Batch add: pick up to [_maxBatch] photos → `POST /wardrobe/batch-upload`
/// (AI detection per image) → review the per-image results → create the
/// selected ones (and attach their photos). The old hardcoded tile grid is
/// gone.
class BatchUploadScreen extends ConsumerStatefulWidget {
  static const path = 'batch-upload';
  static const name = 'wardrobe_batch_upload';

  const BatchUploadScreen({super.key});

  @override
  ConsumerState<BatchUploadScreen> createState() => _BatchUploadScreenState();
}

class _BatchUploadScreenState extends ConsumerState<BatchUploadScreen> {
  static const _maxBatch = 12; // backend MAX_BATCH_SIZE

  final List<PickedImage> _images = [];
  BatchUploadResult? _result;
  final Set<int> _selected = {};
  bool _scanning = false;
  bool _creating = false;

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
    setState(() {
      _images
        ..clear()
        ..addAll(picked);
      _result = null;
      _selected.clear();
      _scanning = true;
    });
    try {
      final result = await ref.read(wardrobeServiceProvider).batchUpload(_images);
      if (!mounted) return;
      setState(() {
        _result = result;
        _scanning = false;
        // Pre-select everything the AI could detect (ok + low-confidence).
        _selected
          ..clear()
          ..addAll(result.results.where((r) => !r.isError).map((r) => r.index));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _scanning = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _addSelected() async {
    final result = _result;
    if (result == null || _selected.isEmpty) return;
    setState(() => _creating = true);

    final entries = <({WardrobeItemInput input, PickedImage? image})>[];
    for (final row in result.results) {
      if (!_selected.contains(row.index) || row.detection == null) continue;
      final d = row.detection!;
      entries.add((
        input: WardrobeItemInput(
          name: d.suggestedName,
          category: d.category,
          colorName: d.color,
          pattern: d.pattern,
          formality: d.formality,
        ),
        image: row.index < _images.length ? _images[row.index] : null,
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

  void _toggle(int index) {
    setState(() {
      if (!_selected.add(index)) _selected.remove(index);
    });
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
              total: _result?.total ?? _images.length,
              selected: _selected.length,
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildBody()),
            if (_result != null && !_scanning)
              _BottomBar(
                count: _selected.length,
                creating: _creating,
                onAddMore: _pickAndScan,
                onContinue: _selected.isEmpty ? null : _addSelected,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_scanning) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.espresso),
            SizedBox(height: 16),
            Text('Analyzing your photos…'),
          ],
        ),
      );
    }
    final result = _result;
    if (result == null) {
      return _EmptyPrompt(onPick: _pickAndScan);
    }
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: result.results.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.78,
      ),
      itemBuilder: (_, i) {
        final row = result.results[i];
        final bytes =
            row.index < _images.length ? _images[row.index].bytes : null;
        return _BatchItemTile(
          row: row,
          bytes: bytes,
          selected: _selected.contains(row.index),
          onTap: row.isError ? null : () => _toggle(row.index),
        );
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
  final int total;
  final int selected;
  const _ProgressLabel({
    required this.scanning,
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
          if (!scanning && total > 0)
            Text(
              '$selected of $total selected',
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

class _BatchItemTile extends StatelessWidget {
  final BatchUploadItem row;
  final Uint8List? bytes;
  final bool selected;
  final VoidCallback? onTap;

  const _BatchItemTile({
    required this.row,
    required this.bytes,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = row.detection != null
        ? row.detection!.category.toUpperCase()
        : 'FAILED';
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
            if (bytes != null)
              Image.memory(bytes!, fit: BoxFit.cover)
            else
              const Center(
                child: Icon(Icons.checkroom_outlined,
                    color: AppColors.taupeSoft, size: 36),
              ),
            if (row.isError)
              Container(color: AppColors.black.withValues(alpha: 0.35)),
            Positioned(
              top: 6,
              right: 6,
              child: _StatusBadge(row: row, selected: selected),
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
  final BatchUploadItem row;
  final bool selected;
  const _StatusBadge({required this.row, required this.selected});

  @override
  Widget build(BuildContext context) {
    late final Color color;
    late final IconData icon;
    if (row.isError) {
      color = AppColors.error;
      icon = Icons.close;
    } else if (!selected) {
      color = AppColors.taupe;
      icon = Icons.circle_outlined;
    } else if (row.suggestManualEntry) {
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
  final VoidCallback onAddMore;
  final VoidCallback? onContinue;

  const _BottomBar({
    required this.count,
    required this.creating,
    required this.onAddMore,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
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
                onTap: creating ? null : onAddMore,
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
