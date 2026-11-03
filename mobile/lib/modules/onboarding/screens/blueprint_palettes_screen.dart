import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_habits_screen.dart';

/// Step 5 of 7 — "Which colours do you gravitate toward?": six palette cards,
/// any number of which can be picked, and an optional "Colours I avoid" row.
///
/// UI only for now: the answers go into the draft, not to the backend (the
/// API is connected later). "Add" under "Colours I avoid" isn't designed
/// yet, so it does nothing.
class BlueprintPalettesScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/palettes';
  static const name = 'blueprint_palettes';

  const BlueprintPalettesScreen({super.key});

  @override
  ConsumerState<BlueprintPalettesScreen> createState() =>
      _BlueprintPalettesScreenState();
}

class _BlueprintPalettesScreenState
    extends ConsumerState<BlueprintPalettesScreen> {
  /// Backend `ColorPalette` literals, their labels and swatches (mockup).
  static const _palettes = <({String value, String label, List<Color> dots})>[
    (
      value: 'neutrals',
      label: 'Neutrals',
      dots: [Color(0xFF1C1A19), Color(0xFF807B77), Color(0xFFF5F0EA)],
    ),
    (
      value: 'earth_tones',
      label: 'Earth tones',
      dots: [Color(0xFF6B4530), Color(0xFFC89E78), Color(0xFF636F48)],
    ),
    (
      value: 'jewel_tones',
      label: 'Jewel tones',
      dots: [Color(0xFF1E2E4A), Color(0xFF1D503E), Color(0xFF652233)],
    ),
    (
      value: 'pastels',
      label: 'Pastels',
      dots: [Color(0xFFE8B8B8), Color(0xFFB6CCE2), Color(0xFFD4E2C8)],
    ),
    (
      value: 'black_white',
      label: 'Black & white',
      dots: [Color(0xFF121110), Color(0xFFFFFFFF), Color(0xFF555350)],
    ),
    (
      value: 'bold_bright',
      label: 'Bold & bright',
      dots: [Color(0xFF1E40AF), Color(0xFFE59E18), Color(0xFFDC2626)],
    ),
  ];

  final _selected = <String>{};
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _selected.addAll(
      ref.read(onboardingControllerProvider).blueprint.colorPalettes,
    );
  }

  void _onContinue() {
    if (_selected.isEmpty || _leaving) return;
    // In card order rather than tap order, so the list is stable.
    final ordered = [
      for (final p in _palettes)
        if (_selected.contains(p.value)) p.value,
    ];
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintPalettes(ordered);
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintHabitsScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlueprintScaffold(
      step: 5,
      canContinue: _selected.isNotEmpty,
      onContinue: _onContinue,
      children: [
        const BlueprintQuestion(
          title: 'Which colours do you gravitate toward?',
          subtitle: 'Select all that apply.',
        ),
        const SizedBox(height: 20),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // The card's badge sits past its corner; leave room so it's not
          // clipped by the grid.
          clipBehavior: Clip.none,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 104,
          ),
          children: [
            for (final p in _palettes)
              _PaletteCard(
                label: p.label,
                dots: p.dots,
                selected: _selected.contains(p.value),
                onTap: () {
                  if (_leaving) return;
                  setState(() {
                    if (!_selected.add(p.value)) _selected.remove(p.value);
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 16),
        const _AvoidRow(),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock, size: 13, color: AppColors.taglineGrey),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                'Stored securely in Canada. 🇨🇦',
                style: BlueprintText.optionSupport(
                  context,
                ).copyWith(fontSize: 11, color: AppColors.taglineGrey),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The mockup's dark brown text.
const _cardInk = Color(0xFF2A1810);

/// Soft card shadow (the mockup's `shadow-espresso-card`).
const _cardShadow = [
  BoxShadow(
    color: Color(0x0F2A1810),
    blurRadius: 24,
    offset: Offset(0, 4),
    spreadRadius: -4,
  ),
];

class _PaletteCard extends StatelessWidget {
  const _PaletteCard({
    required this.label,
    required this.dots,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final List<Color> dots;
  final bool selected;
  final VoidCallback onTap;

  static const _dot = 28.0;
  static const _overlap = 8.0;

  @override
  Widget build(BuildContext context) {
    final card = Material(
      color: selected ? const Color(0xFFFDF5EE) : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected ? AppColors.espresso : Colors.transparent,
          width: 2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Three overlapping swatches, the first on top.
              SizedBox(
                width: dots.length * _dot - (dots.length - 1) * _overlap,
                height: _dot,
                child: Stack(
                  children: [
                    for (var i = dots.length - 1; i >= 0; i--)
                      Positioned(
                        left: i * (_dot - _overlap),
                        child: Container(
                          width: _dot,
                          height: _dot,
                          decoration: BoxDecoration(
                            color: dots[i],
                            shape: BoxShape.circle,
                            border: dots[i] == AppColors.white
                                ? Border.all(color: AppColors.taupeSoft)
                                : null,
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x1A000000),
                                blurRadius: 2,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: BlueprintText.optionSupport(context).copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                  color: selected ? AppColors.espresso : _cardInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: _cardShadow,
              ),
              child: card,
            ),
          ),
          if (selected)
            const Positioned(
              top: -6,
              right: -6,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: AppColors.espresso,
                child: Icon(Icons.check, size: 13, color: AppColors.white),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Colours I avoid — Optional", with an Add pill and an example line.
class _AvoidRow extends StatelessWidget {
  const _AvoidRow();

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _cardShadow,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Colours I avoid',
                    style: body.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _cardInk,
                    ),
                    children: [
                      TextSpan(
                        text: '   Optional',
                        style: body.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: AppColors.taglineGrey,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: AppColors.sand,
                shape: const StadiumBorder(),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  // Not designed yet: shown as in the mockup, does nothing.
                  onTap: () {},
                  child: Container(
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add,
                          size: 14,
                          color: AppColors.espresso,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Add',
                          style: body.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.espresso,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            'e.g., bright orange, neon yellows, magenta',
            style: body.copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: AppColors.taglineGrey,
            ),
          ),
        ),
      ],
    );
  }
}
