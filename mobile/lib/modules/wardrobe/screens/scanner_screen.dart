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
import 'manual_entry_screen.dart' as wardrobe_manual;

/// Scan a single garment: pick/capture a photo → `POST /wardrobe/scan-item`
/// (AI detection) → review → create the item (and attach the photo). The old
/// fake viewfinder is gone; `image_picker` owns capture, so this screen is a
/// capture CTA → preview → result review.
class ScannerScreen extends ConsumerStatefulWidget {
  static const path = 'scan';
  static const name = 'wardrobe_scanner';

  const ScannerScreen({super.key});

  @override
  ConsumerState<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends ConsumerState<ScannerScreen> {
  final _nameController = TextEditingController();

  PickedImage? _image;
  ScanItemResult? _result;
  bool _scanning = false;
  bool _creating = false;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    // Jump straight to the picker; an empty viewfinder isn't useful.
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickAndScan());
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan() async {
    final picked = await pickWardrobeImage(context);
    if (picked == null || !mounted) return;
    setState(() {
      _image = picked;
      _result = null;
      _error = null;
      _scanning = true;
    });
    try {
      final result = await ref.read(wardrobeServiceProvider).scanItem(picked);
      if (!mounted) return;
      _nameController.text = result.detection.suggestedName;
      setState(() {
        _result = result;
        _scanning = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _scanning = false;
      });
    }
  }

  Future<void> _addItem() async {
    final result = _result;
    final image = _image;
    if (result == null || image == null) return;
    if (_nameController.text.trim().isEmpty) {
      _nameController.text = result.detection.suggestedName;
    }
    setState(() => _creating = true);
    final detection = result.detection;
    final input = WardrobeItemInput(
      name: _nameController.text.trim(),
      category: detection.category,
      colorName: detection.color,
      pattern: detection.pattern,
      formality: detection.formality,
    );
    try {
      await ref
          .read(wardrobeControllerProvider.notifier)
          .createItemWithImages(input, [image]);
      ref.invalidate(wardrobeCapacityProvider);
      if (!mounted) return;
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      if (e.statusCode == 429) {
        _showLimitDialog(e.message);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  void _showLimitDialog(String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Wardrobe full'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _manualEntry() {
    // Stay in whichever route tree spawned us — the onboarding-scoped scanner
    // must hand off to the onboarding manual-entry, not the main shell's.
    final inOnboarding = GoRouterState.of(context)
        .matchedLocation
        .startsWith('/onboarding/');
    context.goNamed(inOnboarding
        ? 'onboarding_wardrobe_manual_entry'
        : wardrobe_manual.ManualEntryScreen.name);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        child: Column(
          children: [
            _TopBar(onClose: () => context.pop()),
            Expanded(child: _buildBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final image = _image;
    if (image == null && !_scanning) {
      // Picker was cancelled (or first frame) — offer to start again.
      return _CapturePrompt(onCapture: _pickAndScan, onManual: _manualEntry);
    }

    return Column(
      children: [
        Expanded(child: _Preview(bytes: image?.bytes)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _scanning
              ? const _Analyzing()
              : _error != null
                  ? _ScanError(
                      error: _error!,
                      onRetake: _pickAndScan,
                      onManual: _manualEntry,
                    )
                  : _ResultPanel(
                      result: _result!,
                      nameController: _nameController,
                      creating: _creating,
                      onAdd: _addItem,
                      onRetake: _pickAndScan,
                      onManual: _manualEntry,
                    ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          _CircleIconButton(icon: Icons.close, onTap: onClose),
          const Spacer(),
          Text(
            'SCAN ITEM',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.brandText,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          const SizedBox(width: 40),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.brandText, size: 20),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  final Uint8List? bytes;
  const _Preview({required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xFF1A130C),
      alignment: Alignment.center,
      child: bytes == null
          ? const Icon(Icons.checkroom_outlined,
              color: AppColors.taupeSoft, size: 72)
          : Image.memory(bytes!, fit: BoxFit.contain),
    );
  }
}

class _CapturePrompt extends StatelessWidget {
  final VoidCallback onCapture;
  final VoidCallback onManual;
  const _CapturePrompt({required this.onCapture, required this.onManual});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_a_photo_outlined,
                color: AppColors.brandText, size: 48),
            const SizedBox(height: 16),
            Text(
              'Capture or choose a photo of one item',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.brandText,
                  ),
            ),
            const SizedBox(height: 24),
            _PrimaryButton(label: 'Open Camera / Library', onTap: onCapture),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onManual,
              child: Text(
                'Enter details manually',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppColors.brandText.withValues(alpha: 0.7),
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Analyzing extends StatelessWidget {
  const _Analyzing();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.brandText),
        ),
        const SizedBox(width: 12),
        Text(
          'Analyzing…',
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: AppColors.brandText),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  final ScanItemResult result;
  final TextEditingController nameController;
  final bool creating;
  final VoidCallback onAdd;
  final VoidCallback onRetake;
  final VoidCallback onManual;

  const _ResultPanel({
    required this.result,
    required this.nameController,
    required this.creating,
    required this.onAdd,
    required this.onRetake,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final d = result.detection;
    final label = '${d.confidence}% confident · ${_titleCase(d.category)}';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ConfidenceChip(label: label, warn: result.suggestManualEntry),
        const SizedBox(height: 12),
        if (result.suggestManualEntry)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              "Not fully sure — double-check the details.",
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.brandText.withValues(alpha: 0.7)),
            ),
          ),
        TextField(
          controller: nameController,
          style: const TextStyle(color: AppColors.white),
          decoration: InputDecoration(
            labelText: 'Item name',
            labelStyle: TextStyle(color: AppColors.brandText.withValues(alpha: 0.7)),
            enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.taupe),
            ),
            focusedBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.brandText),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${_titleCase(d.color)} · ${_titleCase(d.pattern)} · ${_titleCase(d.formality)}',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.brandText.withValues(alpha: 0.7)),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(
          label: creating ? 'Adding…' : 'Add This Item',
          onTap: creating ? null : onAdd,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton(
              onPressed: onRetake,
              child: Text('Retake',
                  style: TextStyle(color: AppColors.brandText.withValues(alpha: 0.8))),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: onManual,
              child: Text('Enter manually',
                  style: TextStyle(color: AppColors.brandText.withValues(alpha: 0.8))),
            ),
          ],
        ),
      ],
    );
  }
}

class _ScanError extends StatelessWidget {
  final ApiException error;
  final VoidCallback onRetake;
  final VoidCallback onManual;

  const _ScanError({
    required this.error,
    required this.onRetake,
    required this.onManual,
  });

  @override
  Widget build(BuildContext context) {
    final lowConfidence = error.code == 'low_confidence';
    final message = lowConfidence
        ? "We couldn't identify this confidently. Try another photo or enter the details yourself."
        : error.message;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.brandText),
        ),
        const SizedBox(height: 16),
        _PrimaryButton(label: 'Retake', onTap: onRetake),
        const SizedBox(height: 8),
        TextButton(
          onPressed: onManual,
          child: Text('Enter details manually',
              style: TextStyle(color: AppColors.brandText.withValues(alpha: 0.8))),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const _PrimaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onTap == null ? AppColors.taupe : AppColors.espresso,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfidenceChip extends StatelessWidget {
  final String label;
  final bool warn;
  const _ConfidenceChip({required this.label, this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: (warn ? const Color(0xFFC8901C) : AppColors.sage)
            .withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(warn ? Icons.info_outline : Icons.check_circle,
              color: AppColors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

String _titleCase(String s) => s
    .split(RegExp(r'[\s_]+'))
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');
