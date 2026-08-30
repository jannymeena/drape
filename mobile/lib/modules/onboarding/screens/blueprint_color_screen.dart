import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_lifestyle_screen.dart';

/// Step 4 of 7 — skin undertone and the colour families the user gravitates to.
class BlueprintColorScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/color';
  static const name = 'blueprint_color';

  const BlueprintColorScreen({super.key});

  @override
  ConsumerState<BlueprintColorScreen> createState() =>
      _BlueprintColorScreenState();
}

class _BlueprintColorScreenState extends ConsumerState<BlueprintColorScreen> {
  /// Swatch gradients approximating each undertone, warm → cool → neutral.
  static const _undertones = <(String, String, List<Color>)>[
    ('warm', 'Warm', [Color(0xFFF2D0A9), Color(0xFFC98B4B)]),
    ('cool', 'Cool', [Color(0xFFEBD3CD), Color(0xFFB5808A)]),
    ('neutral', 'Neutral', [Color(0xFFEDDCC7), Color(0xFFB99C7E)]),
  ];

  static const _palettes = <(String, String, List<Color>)>[
    (
      'neutrals',
      'Neutrals',
      [Color(0xFFE5E5E5), Color(0xFFA3A3A3), Color(0xFF525252)]
    ),
    (
      'earth_tones',
      'Earth Tones',
      [Color(0xFF6B4530), Color(0xFF967E67), Color(0xFF53643A)]
    ),
    (
      'jewel_tones',
      'Jewel Tones',
      [Color(0xFF0047AB), Color(0xFF50C878), Color(0xFF800020)]
    ),
    (
      'pastels',
      'Pastels',
      [Color(0xFFFFD1DC), Color(0xFFE0BBE4), Color(0xFFBFFCC6)]
    ),
    (
      'black_white',
      'Black & White',
      [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFA1A1AA)]
    ),
    (
      'bold_bright',
      'Bold & Bright',
      [Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFEC4899)]
    ),
  ];

  String? _undertone;
  final _selectedPalettes = <String>{};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _undertone = saved.undertone;
    _selectedPalettes.addAll(saved.colorPalettes);
  }

  Future<void> _onContinue() async {
    final undertone = _undertone;
    if (undertone == null || _selectedPalettes.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    try {
      final ordered = [
        for (final p in _palettes)
          if (_selectedPalettes.contains(p.$1)) p.$1,
      ];
      await ref.read(onboardingControllerProvider.notifier).setBlueprintColor(
            undertone: undertone,
            palettes: ordered,
          );
      if (!mounted) return;
      context.pushNamed(BlueprintLifestyleScreen.name);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 4,
      canContinue: _undertone != null && _selectedPalettes.isNotEmpty,
      loading: _submitting,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'What’s your undertone?',
          subtitle:
              'This helps us recommend colours that flatter you — a quick guess is fine, you can refine it later with a photo.',
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final (value, label, colors) in _undertones) ...[
              Expanded(
                child: _SwatchTile(
                  label: label,
                  height: 96,
                  selected: _undertone == value,
                  onTap: () {
                    if (_submitting) return;
                    setState(() => _undertone = value);
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: colors,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              if (value != _undertones.last.$1) const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 28),
        const BlueprintQuestion(
          title: 'Which colours do you gravitate toward?',
          subtitle: 'Select all that apply.',
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 14,
          childAspectRatio: 0.82,
          children: [
            for (final (value, label, colors) in _palettes)
              _SwatchTile(
                label: label,
                height: 64,
                selected: _selectedPalettes.contains(value),
                onTap: () {
                  if (_submitting) return;
                  setState(() {
                    if (!_selectedPalettes.add(value)) {
                      _selectedPalettes.remove(value);
                    }
                  });
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final c in colors)
                      Container(
                        width: 14,
                        height: 14,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          color: c,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.taupeSoft),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// A colour swatch (gradient block or dot row) with a caption underneath and a
/// check badge when selected.
class _SwatchTile extends StatelessWidget {
  final String label;
  final double height;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  const _SwatchTile({
    required this.label,
    required this.height,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              Container(
                height: height,
                width: double.infinity,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.espresso : AppColors.taupeSoft,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: child,
              ),
              if (selected)
                const Positioned(
                  top: -4,
                  right: -4,
                  child: CircleAvatar(
                    radius: 10,
                    backgroundColor: AppColors.espresso,
                    child: Icon(Icons.check, size: 13, color: AppColors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: BlueprintText.caption(context).copyWith(
              color: selected ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }
}
