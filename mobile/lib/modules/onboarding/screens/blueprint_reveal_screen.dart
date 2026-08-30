import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_app_bar.dart';
import '../models/style_blueprint_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_goals_screen.dart';
import 'wardrobe_setup_screen.dart';

/// The payoff screen after step 7: plays back everything the seven steps
/// captured, then hands off to wardrobe setup.
///
/// Everything here is derived from the draft the user just filled in — there's
/// no "blueprint" resource on the backend, and inventing one would mean a
/// round-trip for copy we already have locally.
///
/// The back arrow returns to step 7, and from there back through the whole
/// flow; every step prefills from the same draft, so a user who goes back to
/// change an answer finds their previous choices still selected.
class BlueprintRevealScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/reveal';
  static const name = 'blueprint_reveal';

  const BlueprintRevealScreen({super.key});

  @override
  ConsumerState<BlueprintRevealScreen> createState() =>
      _BlueprintRevealScreenState();
}

class _BlueprintRevealScreenState extends ConsumerState<BlueprintRevealScreen> {
  bool _submitting = false;

  // ── Label maps: backend literal → the words we showed the user ──────────
  static const _shoppingStyles = {
    'womens': 'Women’s fashion',
    'mens': 'Men’s fashion',
    'both': 'Both / all styles',
    'prefer_not_to_say': 'Prefer not to say',
  };

  static const _aesthetics = {
    'minimalist': 'Minimalist',
    'rugged': 'Rugged',
    'bohemian': 'Bohemian',
    'professional': 'Professional',
    'streetwear': 'Streetwear',
    'smart_casual': 'Smart Casual',
    'romantic': 'Romantic',
    'avant_garde': 'Avant-Garde',
  };

  static const _shapes = {
    'rectangle': 'Rectangle',
    'triangle': 'Triangle',
    'inverted_triangle': 'Inverted triangle',
    'trapezoid': 'Trapezoid',
    'oval': 'Oval',
    'hourglass': 'Hourglass',
  };

  static const _tops = {
    'slim': 'slim tops',
    'regular': 'regular tops',
    'loose': 'loose tops',
  };

  static const _bottoms = {
    'skinny': 'skinny bottoms',
    'relaxed': 'relaxed bottoms',
    'baggy': 'baggy bottoms',
  };

  static const _undertones = {
    'warm': 'Warm undertone',
    'cool': 'Cool undertone',
    'neutral': 'Neutral undertone',
  };

  static const _paletteNames = {
    'neutrals': 'Neutrals',
    'earth_tones': 'Earth tones',
    'jewel_tones': 'Jewel tones',
    'pastels': 'Pastels',
    'black_white': 'Black & white',
    'bold_bright': 'Bold & bright',
  };

  static const _dressCodes = {
    'casual': 'Casual',
    'business_casual': 'Business casual',
    'business_formal': 'Business formal',
    'uniform_other': 'Uniform / other',
  };

  static const _impressions = {
    'work': 'Work / professional settings',
    'dating': 'Dating / social situations',
    'both': 'Both equally',
    'content': 'Content where I am',
  };

  static const _feelings = {
    'confident': 'Confident and in control',
    'necessity': 'A necessity',
    'frustrated': 'Often frustrated',
    'exploring': 'Ready for a change',
  };

  static const _accessories = {
    'none': 'None at all',
    'minimal': 'Minimal — 1 to 3',
    'statement': 'Statement pieces',
  };

  static const _brandTiers = {
    'fast_fashion': 'Accessible / fast fashion',
    'premium': 'Premium brands',
    'luxury': 'Designer / luxury',
    'mix': 'A high-low mix',
  };

  static const _goals = {
    'time_saving': 'Spend less time choosing outfits',
    'polished': 'Look more polished',
    'maximize_wardrobe': 'Make the most of what I own',
    'discover_style': 'Discover my personal style',
    'confidence': 'Feel more confident',
    'reduce_clutter': 'Reduce closet clutter',
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

  static const _threeMonth = {
    'confident_anywhere': 'Confident wherever I go',
    'found_my_look': 'Found my look',
    'excited_not_stressed': 'Excited to get dressed',
    'proud_no_second_guessing': 'No second-guessing',
  };

  /// Swatches per palette, mirroring step 4 so the reveal shows the colours the
  /// user actually picked rather than a generic set.
  static const _paletteSwatches = <String, List<Color>>{
    'neutrals': [Color(0xFFE5E5E5), Color(0xFFA3A3A3), Color(0xFF525252)],
    'earth_tones': [Color(0xFF6B4530), Color(0xFF967E67), Color(0xFF53643A)],
    'jewel_tones': [Color(0xFF0047AB), Color(0xFF50C878), Color(0xFF800020)],
    'pastels': [Color(0xFFFFD1DC), Color(0xFFE0BBE4), Color(0xFFBFFCC6)],
    'black_white': [Color(0xFF000000), Color(0xFFFFFFFF), Color(0xFFA1A1AA)],
    'bold_bright': [Color(0xFFF97316), Color(0xFFFACC15), Color(0xFFEC4899)],
  };

  String? _join(Iterable<String> values, Map<String, String> labels) {
    final named = [
      for (final v in values)
        if (labels[v] != null) labels[v]!,
    ];
    return named.isEmpty ? null : named.join(' · ');
  }

  /// Headline built from the top two aesthetics. Falls back to a neutral phrase
  /// if step 3 somehow came through empty (a resumed session that skipped
  /// ahead).
  String _headline(StyleBlueprintDraft b) {
    final names = b.styleAesthetics
        .map((a) => _aesthetics[a] ?? a)
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
    // Anchor the row with the brand tones when the user picked nothing, and cap
    // it so the swatches stay a comfortable size.
    if (colors.isEmpty) {
      return const [AppColors.espresso, AppColors.tan, AppColors.sage];
    }
    return colors.take(6).toList();
  }

  /// Back always goes to step 7, even when there's nothing on the stack to pop
  /// — a session resumed straight to the reveal (the splash routes here by
  /// name) would otherwise have no way to change an answer. Step 7 and every
  /// step behind it prefill from the draft, which `loadAndHydrate` seeds on
  /// launch, so the answers are there either way.
  void _onBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(BlueprintGoalsScreen.name);
    }
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Every answer the seven steps collected, grouped the way they were asked.
  /// A row whose value is null is dropped rather than shown empty — the age,
  /// occupation and dress-code questions are all skippable.
  List<Widget> _summary(BuildContext context, OnboardingState state) {
    final b = state.blueprint;
    final fit = _join([b.fitTops, b.fitBottoms].whereType<String>(), {
      ..._tops,
      ..._bottoms,
    });
    final sections = <(String, List<(String, String?)>)>[
      (
        'You',
        [
          ('Shopping for', _shoppingStyles[state.shoppingStyle]),
          ('Age', state.ageRange?.replaceAll('-', '–')),
        ],
      ),
      ('Shape & fit', [('Body shape', _shapes[b.bodyShape]), ('Prefers', fit)]),
      (
        'Style',
        [
          ('Aesthetics', _join(b.styleAesthetics, _aesthetics)),
          ('Undertone', _undertones[b.undertone]),
          ('Colours', _join(b.colorPalettes, _paletteNames)),
        ],
      ),
      (
        'Day to day',
        [
          ('Work', b.occupation),
          ('Dress code', _dressCodes[b.dressCode]),
          ('Dressing to impress', _impressions[b.impressionGoal]),
        ],
      ),
      (
        'Habits',
        [
          ('Shopping feels', _feelings[b.shoppingFeeling]),
          ('Accessories', _accessories[b.accessories]),
          ('Brands', _brandTiers[b.brandTier]),
        ],
      ),
      (
        'Goals',
        [
          ('In three months', _threeMonth[b.threeMonthFeeling]),
          ('Matters most', _join(state.styleGoals, _goals)),
        ],
      ),
    ];

    final out = <Widget>[];
    for (final (title, rows) in sections) {
      final present = [
        for (final (label, value) in rows)
          if (value != null && value.isNotEmpty) (label, value),
      ];
      if (present.isEmpty) continue;
      if (out.isNotEmpty) out.add(const SizedBox(height: 20));
      out.add(_SectionTitle(title));
      out.add(const SizedBox(height: 10));
      for (final (i, (label, value)) in present.indexed) {
        if (i > 0) out.add(const _RowDivider());
        out.add(_SummaryRow(label: label, value: value));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final b = state.blueprint;

    return Scaffold(
      backgroundColor: AppColors.ivory,
      // Back returns to step 7, and from there through the whole flow — each
      // step prefills from the draft, so answers survive the round trip.
      appBar: DrapeAppBar(onBack: _onBack),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
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
                  const SizedBox(height: 32),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final c in _palette(b))
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            // Keeps a white or very pale swatch visible on the
                            // ivory ground.
                            border: Border.all(color: AppColors.taupeSoft),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your palette',
                    textAlign: TextAlign.center,
                    style: BlueprintText.caption(
                      context,
                    ).copyWith(color: AppColors.taglineGrey),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.sand),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _summary(context, state),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      'Tap back to change any of this.',
                      style: BlueprintText.caption(
                        context,
                      ).copyWith(color: AppColors.taglineGrey),
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
                        disabledBackgroundColor: AppColors.taupeSoft,
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
                                valueColor: AlwaysStoppedAnimation(
                                  AppColors.white,
                                ),
                              ),
                            )
                          : Text(
                              'Build My Wardrobe',
                              style: Theme.of(context).textTheme.titleMedium
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
                    style: BlueprintText.caption(
                      context,
                    ).copyWith(color: AppColors.taglineGrey),
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

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: AppColors.espresso,
        letterSpacing: 1.6,
      ),
    );
  }
}

/// One `label — value` line. The label is fixed-width so the values line up
/// down the card.
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: BlueprintText.optionSupport(
                context,
              ).copyWith(color: AppColors.taupe),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: BlueprintText.optionSupport(
                context,
              ).copyWith(color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: AppColors.ivoryWarm);
  }
}
