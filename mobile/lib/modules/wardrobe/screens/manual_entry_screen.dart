import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../profile/screens/compare_plans_screen.dart';
import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';
import '../../../shared/widgets/drape_toast.dart';
import '../image_pick.dart';
import '../models/wardrobe_item.dart';
import '../models/wardrobe_mutations.dart';
import '../wardrobe_controller.dart';
import '../wardrobe_service.dart';

/// Wardrobe-side manual entry — distinct from onboarding's manual_entry
/// (which captures body measurements). Doubles as the edit form: pass [itemId]
/// (via `?id=`) to prefill from `GET /wardrobe/items/{id}` and PATCH on save;
/// omit it to create. Photo capture is SP3 (the tile is a stub here).
class ManualEntryScreen extends ConsumerStatefulWidget {
  static const path = 'manual-entry';
  static const name = 'wardrobe_manual_entry';

  /// Non-null → edit that item; null → create.
  final String? itemId;

  const ManualEntryScreen({super.key, this.itemId});

  @override
  ConsumerState<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends ConsumerState<ManualEntryScreen> {
  // The selectable categories are the backend `Category` literals (minus the
  // "all" filter), so any category can be created — not just the design's five.
  static final _categories =
      WardrobeCategoryFilter.values.where((f) => f != WardrobeCategoryFilter.all).toList();
  static const _colors = <_ColorSwatch>[
    _ColorSwatch('White', Color(0xFFF6F2EC), '#F6F2EC'),
    _ColorSwatch('Black', Color(0xFF1B1B1B), '#1B1B1B'),
    _ColorSwatch('Navy', Color(0xFF1B2D5A), '#1B2D5A'),
    _ColorSwatch('Camel', Color(0xFFC18F5B), '#C18F5B'),
    _ColorSwatch('Olive', Color(0xFF6C7833), '#6C7833'),
    _ColorSwatch('Grey', Color(0xFF9C9A95), '#9C9A95'),
  ];
  static const _seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
  static const _formality = ['Casual', 'Smart Casual', 'Formal'];
  static const _formalityLiterals = ['casual', 'smart_casual', 'formal'];

  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _descriptionController = TextEditingController();

  int _categoryIndex = 0;
  int? _colorIndex;
  final Set<int> _seasonIndices = {};
  int _formalityIndex = 0;

  bool _submitting = false;
  String? _nameError;
  bool _prefilled = false;

  bool get _isEditing => widget.itemId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _prefill(WardrobeItem item) {
    if (_prefilled) return;
    _prefilled = true;
    _nameController.text = item.name;
    if (item.purchasePrice != null) {
      _priceController.text = item.purchasePrice!.toStringAsFixed(2);
    }
    _descriptionController.text = item.description ?? '';
    final cat = _categories.indexWhere((f) => f.query == item.category);
    if (cat >= 0) _categoryIndex = cat;
    if (item.colorName != null) {
      final color = _colors
          .indexWhere((c) => c.label.toLowerCase() == item.colorName!.toLowerCase());
      if (color >= 0) _colorIndex = color;
    }
    for (final s in item.season ?? const <String>[]) {
      final idx = _seasons.indexWhere((label) => label.toLowerCase() == s);
      if (idx >= 0) _seasonIndices.add(idx);
    }
    final form = _formalityLiterals.indexWhere((f) => f == item.formality);
    if (form >= 0) _formalityIndex = form;
  }

  @override
  Widget build(BuildContext context) {
    // In edit mode, wait for the item, then prefill the form once.
    if (_isEditing && !_prefilled) {
      final item = ref.watch(wardrobeItemProvider(widget.itemId!));
      return item.when(
        loading: () => const _Scaffolded(
          title: 'Edit Item',
          child: Center(
            child: CircularProgressIndicator(color: AppColors.espresso),
          ),
        ),
        error: (e, _) => _Scaffolded(
          title: 'Edit Item',
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                e is ApiException ? e.message : "We couldn't load this item.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ),
        data: (item) {
          _prefill(item);
          return _form(context);
        },
      );
    }
    return _form(context);
  }

  Widget _form(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              title: _isEditing ? 'Edit Item' : 'Add Item',
              onBack: () => context.pop(),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _PhotoTile(
                    label: _isEditing ? 'ADD PHOTO' : 'PHOTO AFTER SAVING',
                    onTap: _photoTileTapped,
                  ),
                  const SizedBox(height: 20),
                  DrapeTextField(
                    label: 'Item Name',
                    controller: _nameController,
                    errorText: _nameError,
                    textInputAction: TextInputAction.next,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    label: 'CATEGORY',
                    child: _ChipRow(
                      options: _categories.map((f) => f.label).toList(),
                      selectedIndex: _categoryIndex,
                      onSelected: (i) => setState(() => _categoryIndex = i),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    label: 'COLOR',
                    child: _ColorSwatchRow(
                      colors: _colors,
                      selectedIndex: _colorIndex,
                      onSelected: (i) => setState(
                          () => _colorIndex = _colorIndex == i ? null : i),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    label: 'SEASON',
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < _seasons.length; i++)
                          _SelectChip(
                            label: _seasons[i],
                            selected: _seasonIndices.contains(i),
                            onTap: () => setState(() {
                              if (!_seasonIndices.add(i)) {
                                _seasonIndices.remove(i);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Section(
                    label: 'FORMALITY',
                    child: _ChipRow(
                      options: _formality,
                      selectedIndex: _formalityIndex,
                      onSelected: (i) => setState(() => _formalityIndex = i),
                    ),
                  ),
                  const SizedBox(height: 20),
                  DrapeTextField(
                    label: r'$ Purchase Price',
                    controller: _priceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 20),
                  DrapeTextField(
                    label: 'Description',
                    controller: _descriptionController,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: DrapeButton(
                label: _isEditing ? 'Save Changes' : 'Add to Wardrobe',
                loading: _submitting,
                leading: const Icon(Icons.inventory_2_outlined,
                    color: AppColors.white, size: 18),
                onPressed: _submitting ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  WardrobeItemInput _buildInput() {
    final price = double.tryParse(_priceController.text.trim());
    final color = _colorIndex == null ? null : _colors[_colorIndex!];
    final description = _descriptionController.text.trim();
    return WardrobeItemInput(
      name: _nameController.text.trim(),
      category: _categories[_categoryIndex].query,
      colorName: color?.label.toLowerCase(),
      colorHex: color?.hex,
      formality: _formalityLiterals[_formalityIndex],
      season: _seasonIndices.isEmpty
          ? null
          : (_seasonIndices.toList()..sort())
              .map((i) => _seasons[i].toLowerCase())
              .toList(),
      purchasePrice: price,
      description: description.isEmpty ? null : description,
    );
  }

  Future<void> _photoTileTapped() async {
    if (!_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Save the item first, then add photos from its page.'),
        ),
      );
      return;
    }
    final picked = await pickWardrobeImage(context);
    if (picked == null || !mounted) return;
    try {
      await ref
          .read(wardrobeControllerProvider.notifier)
          .addImages(widget.itemId!, [picked]);
      ref.invalidate(wardrobeItemProvider(widget.itemId!));
      if (!mounted) return;
      showDrapeToast(context, 'Photo added');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Give your item a name.');
      return;
    }
    setState(() => _submitting = true);
    final controller = ref.read(wardrobeControllerProvider.notifier);
    try {
      if (_isEditing) {
        await controller.updateItem(widget.itemId!, _buildInput());
        ref.invalidate(wardrobeItemProvider(widget.itemId!));
        if (!mounted) return;
        showDrapeToast(context, 'Changes saved');
      } else {
        final capacityBefore =
            ref.read(wardrobeCapacityProvider).valueOrNull;
        await controller.createItem(_buildInput());
        ref.invalidate(wardrobeCapacityProvider);
        if (!mounted) return;
        showDrapeToast(
          context,
          'Item added to wardrobe!',
          trailing: capacityBefore?.toastDetailAfterAdding(1),
        );
      }
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
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
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.goNamed(ComparePlansScreen.name);
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }
}

/// Minimal Scaffold used for the edit-mode loading/error states (keeps the
/// header + back button while the item resolves).
class _Scaffolded extends StatelessWidget {
  final String title;
  final Widget child;
  const _Scaffolded({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(title: title, onBack: () => context.pop()),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const _Header({required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 12, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.espresso),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
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

class _PhotoTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _PhotoTile({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 13,
        child: Material(
          color: AppColors.tanFixed.withValues(alpha: 0.5),
          child: InkWell(
            onTap: onTap,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_a_photo_outlined,
                      color: AppColors.espresso, size: 40),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.espresso,
                          letterSpacing: 1.6,
                          fontWeight: FontWeight.w700,
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

class _Section extends StatelessWidget {
  final String label;
  final Widget child;
  const _Section({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.taupe,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        child,
      ],
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> options;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const _ChipRow({
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            _SelectChip(
              label: options[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
            if (i < options.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.espresso : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: selected ? AppColors.espresso : AppColors.taupeSoft,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: selected ? AppColors.white : AppColors.ink,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _ColorSwatch {
  final String label;
  final Color color;
  final String hex;
  const _ColorSwatch(this.label, this.color, this.hex);
}

class _ColorSwatchRow extends StatelessWidget {
  final List<_ColorSwatch> colors;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  const _ColorSwatchRow({
    required this.colors,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < colors.length; i++) ...[
            _ColorTile(
              swatch: colors[i],
              selected: i == selectedIndex,
              onTap: () => onSelected(i),
            ),
            if (i < colors.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
    );
  }
}

class _ColorTile extends StatelessWidget {
  final _ColorSwatch swatch;
  final bool selected;
  final VoidCallback onTap;

  const _ColorTile({
    required this.swatch,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: swatch.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? AppColors.espresso : AppColors.taupeSoft,
                width: selected ? 2 : 1,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            swatch.label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.taupe,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
