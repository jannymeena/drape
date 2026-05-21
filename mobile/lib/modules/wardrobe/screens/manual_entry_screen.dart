import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import '../../../shared/widgets/drape_text_field.dart';

/// Wardrobe-side manual entry — distinct from onboarding's manual_entry
/// (which captures body measurements).
class ManualEntryScreen extends StatefulWidget {
  static const path = 'manual-entry';
  static const name = 'wardrobe_manual_entry';

  const ManualEntryScreen({super.key});

  @override
  State<ManualEntryScreen> createState() => _ManualEntryScreenState();
}

class _ManualEntryScreenState extends State<ManualEntryScreen> {
  static const _categories = ['Tops', 'Bottoms', 'Skirts/Dresses', 'Outerwear', 'Shoes'];
  static const _colors = <_ColorSwatch>[
    _ColorSwatch('White', Color(0xFFF6F2EC)),
    _ColorSwatch('Black', Color(0xFF1B1B1B)),
    _ColorSwatch('Navy', Color(0xFF1B2D5A)),
    _ColorSwatch('Camel', Color(0xFFC18F5B)),
    _ColorSwatch('Olive', Color(0xFF6C7833)),
    _ColorSwatch('Grey', Color(0xFF9C9A95)),
  ];
  static const _seasons = ['Spring', 'Summer', 'Fall', 'Winter'];
  static const _formality = ['Casual', 'Smart Casual', 'Formal'];

  int _categoryIndex = 2;
  int _colorIndex = 0;
  final Set<int> _seasonIndices = {};
  int _formalityIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            _Header(onBack: () => context.pop()),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                children: [
                  _PhotoTile(),
                  const SizedBox(height: 20),
                  const DrapeTextField(label: 'Item Name'),
                  const SizedBox(height: 20),
                  _Section(
                    label: 'CATEGORY',
                    child: _ChipRow(
                      options: _categories,
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
                      onSelected: (i) => setState(() => _colorIndex = i),
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
                      onSelected: (i) =>
                          setState(() => _formalityIndex = i),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const DrapeTextField(
                    label: r'$ Purchase Price',
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 20),
                  const DrapeTextField(label: 'Description'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: DrapeButton(
                label: 'Add to Wardrobe',
                leading: const Icon(
                  Icons.inventory_2_outlined,
                  color: AppColors.white,
                  size: 18,
                ),
                onPressed: () {
                  debugPrint('manual: add to wardrobe');
                  context.pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;
  const _Header({required this.onBack});

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
              'Add Item',
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
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 16 / 13,
        child: Container(
          color: AppColors.tanFixed.withValues(alpha: 0.5),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_a_photo_outlined,
                  color: AppColors.espresso, size: 40),
              const SizedBox(height: 8),
              Text(
                'UPDATE PHOTO',
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
          padding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
  const _ColorSwatch(this.label, this.color);
}

class _ColorSwatchRow extends StatelessWidget {
  final List<_ColorSwatch> colors;
  final int selectedIndex;
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
