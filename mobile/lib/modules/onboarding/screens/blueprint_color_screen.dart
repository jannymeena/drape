import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/theme/app_colors.dart';
import '../models/skin_shades.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_palettes_screen.dart';

/// Step 4 of 7 — "What's your skin tone?": a shade on a 1–10 scale, with the
/// colours that flatter it, and the undertone. Both are needed to continue;
/// "Skip for now" moves on without either.
class BlueprintColorScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/color';
  static const name = 'blueprint_color';

  const BlueprintColorScreen({super.key});

  @override
  ConsumerState<BlueprintColorScreen> createState() =>
      _BlueprintColorScreenState();
}

class _BlueprintColorScreenState extends ConsumerState<BlueprintColorScreen> {
  /// Each undertone's swatch (a skin gradient) and its tell.
  static const _undertones =
      <({String value, String label, String hint, List<Color> gradient})>[
        (
          value: 'warm',
          label: 'Warm',
          hint: 'Gold jewellery suits you. Veins look greenish.',
          gradient: [Color(0xFFF0C9A0), Color(0xFFD8A474)],
        ),
        (
          value: 'cool',
          label: 'Cool',
          hint: 'Silver suits you. Veins look bluish.',
          gradient: [Color(0xFFE8C1C1), Color(0xFFD29A9A)],
        ),
        (
          value: 'neutral',
          label: 'Neutral',
          hint: 'Both silver and gold work effortlessly.',
          gradient: [Color(0xFFE6D2C1), Color(0xFFC8A990)],
        ),
      ];

  int? _shade;
  String? _undertone;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).blueprint;
    _shade = skinShade(saved.skinShade)?.number;
    _undertone = saved.undertone;
  }

  /// Records the answers (or none, for [skip]) and moves straight on; the
  /// save runs in the background, and a failure is retried with the next
  /// step's save.
  void _leave({bool skip = false}) {
    if (_leaving) return;
    if (!skip && (_shade == null || _undertone == null)) return;
    // Saved in the background; see OnboardingController._save.
    ref
        .read(onboardingControllerProvider.notifier)
        .setBlueprintColor(
          skinShade: skip ? null : _shade,
          undertone: skip ? null : _undertone,
        );
    // Ignore further taps until the user comes back to this step.
    setState(() => _leaving = true);
    context.pushNamed(BlueprintPalettesScreen.name).whenComplete(() {
      if (mounted) setState(() => _leaving = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final shade = skinShade(_shade);
    return BlueprintScaffold(
      step: 4,
      canContinue: _shade != null && _undertone != null,
      onContinue: _leave,
      children: [
        const BlueprintQuestion(
          title: 'What’s your skin tone?',
          subtitle: 'We only use this to suggest colours that flatter you.',
        ),
        const SizedBox(height: 24),
        _SectionLabel(
          'Your shade',
          trailing: shade == null
              ? null
              : 'Tone ${shade.number.toString().padLeft(2, '0')} Selected',
        ),
        const SizedBox(height: 12),
        _ShadeGrid(
          selected: _shade,
          onSelect: (n) {
            if (!_leaving) setState(() => _shade = n);
          },
        ),
        if (shade != null) ...[
          const SizedBox(height: 12),
          _FlatteringStrip(colors: shade.flattering),
        ],
        const SizedBox(height: 24),
        const _SectionLabel('Your undertone'),
        const SizedBox(height: 2),
        Text(
          'A quick guess is fine, you can refine it later with a photo.',
          style: BlueprintText.optionSupport(
            context,
          ).copyWith(fontSize: 12, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 10),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final u in _undertones) ...[
                Expanded(
                  child: _UndertoneCard(
                    label: u.label,
                    hint: u.hint,
                    gradient: u.gradient,
                    selected: _undertone == u.value,
                    onTap: () {
                      if (!_leaving) setState(() => _undertone = u.value);
                    },
                  ),
                ),
                if (u != _undertones.last) const SizedBox(width: 10),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: InkWell(
            // The jewellery test isn't designed yet: the link is shown, as in
            // the mockup, but does nothing for now.
            onTap: () {},
            borderRadius: BorderRadius.circular(999),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.help_outline,
                    size: 16,
                    color: AppColors.espressoDark,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Not sure? Try the 10-second jewellery test',
                      style: BlueprintText.optionSupport(context).copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: AppColors.espressoDark,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.espressoDark.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right,
                    size: 14,
                    color: AppColors.espressoDark,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: () => _leave(skip: true),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.inkSoft.withValues(alpha: 0.75),
            ),
            child: Text(
              'Skip for now',
              style: BlueprintText.optionSupport(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.inkSoft.withValues(alpha: 0.75),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.ivoryDim,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock, size: 13, color: AppColors.sage),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Skin tone parameters stored securely in Canada 🇨🇦',
                    style: BlueprintText.optionSupport(context).copyWith(
                      fontSize: 11,
                      color: AppColors.inkSoft.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// A small uppercase section heading, with an optional note at the right.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.trailing});

  final String text;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            text.toUpperCase(),
            style: body.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 2,
              color: AppColors.inkSoft.withValues(alpha: 0.8),
            ),
          ),
        ),
        if (trailing case final note?)
          Text(
            note,
            style: body.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.espressoDark,
            ),
          ),
      ],
    );
  }
}

/// The ten shades, two rows of five, on a soft panel: 50 pt swatches in
/// five equal columns, as in the mockup, shrinking only on a screen too
/// narrow for five of them.
class _ShadeGrid extends StatelessWidget {
  const _ShadeGrid({required this.selected, required this.onSelect});

  final int? selected;
  final ValueChanged<int> onSelect;

  static const _padding = 14.0;
  static const _columnGap = 10.0;
  static const _rowGap = 14.0;
  static const _swatch = 50.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final column = (box.maxWidth - 2 * _padding - 4 * _columnGap) / 5;
        // Room for the selected ring (4 pt out) and its scale-up.
        final d = (column - 6).clamp(28.0, _swatch);
        return Container(
          padding: const EdgeInsets.all(_padding),
          decoration: BoxDecoration(
            color: AppColors.ivoryDim,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final row in [
                skinShades.sublist(0, 5),
                skinShades.sublist(5),
              ])
                Padding(
                  padding: EdgeInsets.only(
                    top: row.first.number == 1 ? 0 : _rowGap,
                  ),
                  child: Row(
                    children: [
                      for (final shade in row) ...[
                        Expanded(
                          child: Center(
                            child: _ShadeSwatch(
                              shade: shade,
                              diameter: d,
                              selected: shade.number == selected,
                              onTap: () => onSelect(shade.number),
                            ),
                          ),
                        ),
                        if (shade != row.last)
                          const SizedBox(width: _columnGap),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ShadeSwatch extends StatelessWidget {
  const _ShadeSwatch({
    required this.shade,
    required this.diameter,
    required this.selected,
    required this.onTap,
  });

  final SkinShade shade;
  final double diameter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = diameter;
    // Selected: the swatch keeps its size and a dark ring goes round it,
    // set off by a gap the colour of the panel.
    const ringGap = 2.0;
    const ringWidth = 2.0;
    const ringOut = ringGap + ringWidth;
    final swatch = SizedBox.square(
      dimension: d,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: shade.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.taupeSoft.withValues(alpha: 0.45),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(
                      alpha: selected ? 0.16 : 0.06,
                    ),
                    blurRadius: selected ? 8 : 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ),
          if (selected) ...[
            const Positioned(
              left: -ringOut,
              top: -ringOut,
              right: -ringOut,
              bottom: -ringOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.espressoDark, width: ringWidth),
                  ),
                ),
              ),
            ),
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: AppColors.espressoDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check,
                  size: 11,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: 'Shade ${shade.number} of 10',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: selected ? 1.05 : 1,
              duration: const Duration(milliseconds: 200),
              child: swatch,
            ),
            const SizedBox(height: 6),
            Text(
              '${shade.number}',
              style: BlueprintText.optionSupport(context).copyWith(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? AppColors.espressoDark : AppColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Colours that flatter you": the chosen shade's five colours.
class _FlatteringStrip extends StatelessWidget {
  const _FlatteringStrip({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F2A1810),
            blurRadius: 24,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.palette, size: 18, color: AppColors.espressoDark),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Colours that flatter you',
              style: BlueprintText.optionSupport(context).copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
          ),
          for (final c in colors)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(left: 6),
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: c,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.taupeSoft.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UndertoneCard extends StatelessWidget {
  const _UndertoneCard({
    required this.label,
    required this.hint,
    required this.gradient,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String hint;
  final List<Color> gradient;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? const Color(0xFFFDF5EE) : AppColors.white,
        elevation: selected ? 1 : 0,
        shadowColor: const Color(0x332A1810),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.espressoDark : Colors.transparent,
            width: 2,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 36,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: BlueprintText.optionSupport(context).copyWith(
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w500,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hint,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: BlueprintText.optionSupport(context).copyWith(
                        fontSize: 10,
                        height: 1.25,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected)
                const Positioned(
                  top: 6,
                  right: 6,
                  child: CircleAvatar(
                    radius: 8,
                    backgroundColor: AppColors.espresso,
                    child: Icon(Icons.check, size: 10, color: AppColors.white),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
