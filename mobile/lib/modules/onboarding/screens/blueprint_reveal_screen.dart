import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/style_blueprint_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'wardrobe_setup_screen.dart';

/// The payoff screen after step 7: plays back what the seven steps captured,
/// then hands off to wardrobe setup.
///
/// Everything here is derived from the draft the user just filled in — there's
/// no "blueprint" resource on the backend, and inventing one would mean a
/// round-trip for copy we already have locally.
class BlueprintRevealScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/reveal';
  static const name = 'blueprint_reveal';

  const BlueprintRevealScreen({super.key});

  @override
  ConsumerState<BlueprintRevealScreen> createState() =>
      _BlueprintRevealScreenState();
}

class _BlueprintRevealScreenState
    extends ConsumerState<BlueprintRevealScreen> {
  bool _submitting = false;

  static const _aestheticLabels = {
    'minimalist': 'Minimalist',
    'rugged': 'Rugged',
    'bohemian': 'Bohemian',
    'professional': 'Professional',
    'streetwear': 'Streetwear',
    'smart_casual': 'Smart Casual',
    'romantic': 'Romantic',
    'avant_garde': 'Avant-Garde',
  };

  static const _shapeLabels = {
    'rectangle': 'Rectangle',
    'triangle': 'Triangle',
    'inverted_triangle': 'Inverted triangle',
    'trapezoid': 'Trapezoid',
    'oval': 'Oval',
    'hourglass': 'Hourglass',
  };

  static const _fitLabels = {
    'slim': 'slim fit',
    'regular': 'regular fit',
    'loose': 'loose fit',
    'skinny': 'skinny fit',
    'relaxed': 'relaxed fit',
    'baggy': 'baggy fit',
  };

  static const _undertoneLabels = {
    'warm': 'Warm undertone',
    'cool': 'Cool undertone',
    'neutral': 'Neutral undertone',
  };

  /// The aspiration line, echoed back as the reason the blueprint exists.
  static const _feelingLines = {
    'confident_anywhere':
        'You told us you want to feel confident wherever you go — that’s exactly what we’re building toward.',
    'found_my_look':
        'You told us you want to finally find your look — that’s exactly what we’re building toward.',
    'excited_not_stressed':
        'You told us you want getting dressed to feel exciting, not stressful — that’s exactly what we’re building toward.',
    'proud_no_second_guessing':
        'You told us you want to show up without second-guessing — that’s exactly what we’re building toward.',
  };

  /// Swatch sets per palette, reused from the step-4 chips so the reveal shows
  /// the colours the user actually picked.
  static const _paletteSwatches = <String, List<Color>>{
    'neutrals': [Color(0xFFE5E5E5), Color(0xFFA3A3A3), Color(0xFF525252)],
    'earth_tones': [Color(0xFF6B4530), Color(0xFF967E67), Color(0xFF53643A)],
    'jewel_tones': [Color(0xFF0047AB), Color(0xFF50C878), Color(0xFF800020)],
    'pastels': [Color(0xFFFFD1DC), Color(0xFFE0BBE4), Color(0xFFBFFCC6)],
    'black_white': [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFA1A1AA)],
    'bold_bright': [Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFEC4899)],
  };

  /// Headline built from the top two aesthetics, e.g. "Minimalist, Smart
  /// Casual". Falls back to a neutral phrase if step 3 somehow came through
  /// empty (a resumed session that skipped ahead).
  String _headline(StyleBlueprintDraft b) {
    final names = b.styleAesthetics
        .map((a) => _aestheticLabels[a] ?? a)
        .take(2)
        .toList();
    if (names.isEmpty) return 'Your Style, Defined';
    return '${names.join(', ')},\nWorn with Confidence';
  }

  List<Color> _palette(StyleBlueprintDraft b) {
    final colors = <Color>[];
    for (final p in b.colorPalettes) {
      colors.addAll(_paletteSwatches[p] ?? const []);
    }
    // Anchor the row with the brand tones when the user picked nothing, and
    // cap it so the swatches stay comfortably tappable-sized.
    if (colors.isEmpty) {
      return const [AppColors.espresso, AppColors.tan, AppColors.sage];
    }
    return colors.take(6).toList();
  }

  String? _fitLine(StyleBlueprintDraft b) {
    final shape = _shapeLabels[b.bodyShape];
    final fit = _fitLabels[b.fitTops];
    if (shape == null && fit == null) return null;
    return [shape, fit].where((e) => e != null).join(', ');
  }

  Future<void> _onContinue() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(onboardingControllerProvider.notifier).completeBlueprint();
      if (!mounted) return;
      context.pushNamed(WardrobeSetupScreen.name);
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
    final state = ref.watch(onboardingControllerProvider);
    final b = state.blueprint;
    final aesthetics = b.styleAesthetics
        .map((a) => _aestheticLabels[a] ?? a)
        .join(' · ');
    final fitLine = _fitLine(b);
    final undertone = _undertoneLabels[b.undertone];

    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                children: [
                  Text(
                    'YOUR STYLE BLUEPRINT',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.taglineGrey,
                          letterSpacing: 2.4,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _headline(b),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: AppColors.ink,
                          height: 1.2,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _feelingLines[b.threeMonthFeeling] ??
                        'Here’s what we learned about how you want to dress.',
                    textAlign: TextAlign.center,
                    style: BlueprintText.subtitle(context),
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in _palette(b))
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.taupeSoft),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your palette',
                    textAlign: TextAlign.center,
                    style: BlueprintText.caption(context)
                        .copyWith(color: AppColors.taglineGrey),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: Column(
                      children: [
                        if (aesthetics.isNotEmpty)
                          _SummaryRow(
                            icon: Icons.checkroom,
                            label: aesthetics,
                          ),
                        if (fitLine != null) ...[
                          const _SummaryDivider(),
                          _SummaryRow(icon: Icons.straighten, label: fitLine),
                        ],
                        if (undertone != null) ...[
                          const _SummaryDivider(),
                          _SummaryRow(
                            icon: Icons.wb_sunny_outlined,
                            label: undertone,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: AppColors.ivory,
                border: Border(top: BorderSide(color: AppColors.sand)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _submitting ? null : _onContinue,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.espresso,
                        foregroundColor: AppColors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation(AppColors.white),
                              ),
                            )
                          : Text(
                              'Build My Wardrobe',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Takes 10 seconds — no card required',
                    style: BlueprintText.caption(context)
                        .copyWith(color: AppColors.taglineGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SummaryRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.espresso),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: BlueprintText.option(context))),
      ],
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Divider(height: 1, color: AppColors.sand),
    );
  }
}
