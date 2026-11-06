import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/theme/app_colors.dart';
import '../models/body_shapes.dart';
import '../models/skin_shades.dart';
import '../models/style_blueprint_draft.dart';
import '../onboarding_controller.dart';
import '../widgets/blueprint_scaffold.dart';
import 'blueprint_goals_screen.dart';
import 'blueprint_identity_screen.dart';
import 'wardrobe_setup_screen.dart';
import '../widgets/pipeda_note.dart';

/// After step 8: "builds" the Style Blueprint, then reveals it, and hands
/// off to wardrobe setup.
///
/// Building is waiting for every step's background save to land (retrying
/// any that failed), shown for at least [minBuilding] so the moment reads.
/// If a save still fails, the error state offers to try again or to go back
/// to step 8. The blueprint itself is derived from the draft the user just
/// filled in; there's no "blueprint" resource on the backend.
class BlueprintRevealScreen extends ConsumerStatefulWidget {
  static const path = '/onboarding/blueprint/reveal';
  static const name = 'blueprint_reveal';

  const BlueprintRevealScreen({super.key, this.minBuilding = _building});

  /// How long the building state shows at least.
  final Duration minBuilding;
  static const _building = Duration(milliseconds: 3600);

  @override
  ConsumerState<BlueprintRevealScreen> createState() =>
      _BlueprintRevealScreenState();
}

enum _Phase { building, ready, failed }

class _BlueprintRevealScreenState extends ConsumerState<BlueprintRevealScreen> {
  _Phase _phase = _Phase.building;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _build();
  }

  Future<void> _build() async {
    if (_phase != _Phase.building) setState(() => _phase = _Phase.building);
    final saved = ref.read(onboardingControllerProvider.notifier).ensureSaved();
    var ok = true;
    try {
      await Future.wait([
        saved,
        if (widget.minBuilding > Duration.zero)
          Future<void>.delayed(widget.minBuilding),
      ]);
    } on ApiException {
      ok = false;
    }
    if (mounted) setState(() => _phase = ok ? _Phase.ready : _Phase.failed);
  }

  /// Back always reaches step 8, even with nothing on the stack to pop (a
  /// session resumed straight to the reveal). Every step prefills from the
  /// draft, so the answers are there either way.
  void _toStep8() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed(BlueprintGoalsScreen.name);
    }
  }

  Future<void> _onBuildWardrobe() async {
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingControllerProvider);
    final child = switch (_phase) {
      _Phase.building => const _Building(),
      _Phase.ready => _Result(
        state: state,
        submitting: _submitting,
        onBuildWardrobe: _onBuildWardrobe,
        // Edit starts the steps over from step 1, every answer prefilled.
        onEdit: () => context.goNamed(BlueprintIdentityScreen.name),
      ),
      _Phase.failed => _Failed(
        recorded:
            kBlueprintSteps -
            ref.read(onboardingControllerProvider.notifier).unsavedSteps,
        onRetry: _build,
        onResume: _toStep8,
      ),
    };
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _toStep8();
      },
      child: Scaffold(
        backgroundColor: AppColors.ivory,
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: KeyedSubtree(key: ValueKey(_phase), child: child),
          ),
        ),
      ),
    );
  }
}

/// The small uppercase "YOUR STYLE BLUEPRINT" over each state.
class _Eyebrow extends StatelessWidget {
  const _Eyebrow({this.color = AppColors.taupe, this.spacing = 1.8});

  final Color color;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      'YOUR STYLE BLUEPRINT',
      textAlign: TextAlign.center,
      style: BlueprintText.optionSupport(context).copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: spacing,
        color: color,
      ),
    );
  }
}

// ─── Building ─────────────────────────────────────────────────────────────

class _Building extends StatefulWidget {
  const _Building();

  @override
  State<_Building> createState() => _BuildingState();
}

class _BuildingState extends State<_Building>
    with SingleTickerProviderStateMixin {
  static const _phrases = [
    ('Reading your answers…', 0),
    ('Choosing your colours…', 1),
    ('Balancing tone & silhouettes…', 1),
    ('Writing your blueprint…', 2),
    ('Finalising your bespoke edit…', 2),
  ];
  static const _stages = ['Curating', 'Harmonising', 'Composing'];
  static const _dots = [
    Color(0xFF6B4530),
    Color(0xFF8B9E6E),
    Color(0xFFF5E8D8),
    Color(0xFFD4C0B0),
    Color(0xFF2A1810),
  ];

  late final AnimationController _beat = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();
  late final Timer _ticker;
  int _phrase = 0;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (mounted) setState(() => _phrase = (_phrase + 1) % _phrases.length);
    });
  }

  @override
  void dispose() {
    _ticker.cancel();
    _beat.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    final (text, stage) = _phrases[_phrase];
    return Stack(
      children: [
        // A soft, breathing warmth behind the content.
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _beat,
              builder: (context, _) {
                final pulse = 0.85 + 0.15 * math.sin(_beat.value * 2 * math.pi);
                return ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 320,
                        height: 320,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFFF0BBA0,
                          ).withValues(alpha: 0.2 * pulse),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(32, -48),
                        child: Container(
                          width: 256,
                          height: 256,
                          decoration: BoxDecoration(
                            color: AppColors.sageDim.withValues(alpha: 0.3),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 40, 28, 16),
          child: Column(
            children: [
              Opacity(
                opacity: 0.4,
                child: Text(
                  'ATELIER Nº 04 — SYNTHESIS',
                  style: BlueprintText.heading(context).copyWith(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 2.4,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              const Spacer(),
              const _Eyebrow(spacing: 2),
              const SizedBox(height: 8),
              Container(
                width: 16,
                height: 1,
                color: AppColors.taupeSoft.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 40),
              AnimatedBuilder(
                animation: _beat,
                builder: (context, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (i, c) in _dots.indexed) ...[
                      Transform.translate(
                        // Each dot bobs a beat behind the last.
                        offset: Offset(
                          0,
                          -6 *
                              math
                                  .sin((_beat.value - i * 0.2) * 2 * math.pi)
                                  .clamp(0.0, 1.0),
                        ),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: c.withValues(alpha: 0.35),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (i < _dots.length - 1) const SizedBox(width: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              SizedBox(
                height: 32,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: Text(
                    text,
                    key: ValueKey(text),
                    style: body.copyWith(
                      fontSize: 14,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 24,
                runSpacing: 8,
                children: [
                  for (final (i, name) in _stages.indexed)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i <= stage
                                ? AppColors.espressoDark
                                : AppColors.taupeSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          name,
                          style: body.copyWith(
                            fontSize: 11,
                            letterSpacing: 0.55,
                            fontWeight: i == stage
                                ? FontWeight.w500
                                : FontWeight.w400,
                            color: i == stage
                                ? AppColors.espressoDark
                                : AppColors.taupe.withValues(
                                    alpha: i < stage ? 0.8 : 0.5,
                                  ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 40),
              Container(
                constraints: const BoxConstraints(maxWidth: 240),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.ivoryDim,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D000000),
                      blurRadius: 2,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.auto_fix_high,
                      size: 16,
                      color: AppColors.taupe,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Calibrating drape, tone, and silhouette profile',
                        style: body.copyWith(
                          fontSize: 12,
                          height: 1.25,
                          color: AppColors.inkSoft,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const PipedaNote(),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Result ───────────────────────────────────────────────────────────────

class _Result extends StatelessWidget {
  const _Result({
    required this.state,
    required this.submitting,
    required this.onBuildWardrobe,
    required this.onEdit,
  });

  final OnboardingState state;
  final bool submitting;
  final VoidCallback onBuildWardrobe;
  final VoidCallback onEdit;

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

  static const _undertones = {
    'warm': 'Warm',
    'cool': 'Cool',
    'neutral': 'Neutral',
  };

  static const _dressCodes = {
    'casual': 'Casual dress code',
    'smart_casual': 'Smart casual',
    'business_casual': 'Business casual',
    'business_formal': 'Business formal',
    'uniform_other': 'Uniform',
  };

  /// The aspiration, echoed back as the reason the blueprint exists.
  static const _feelingLines = {
    'confident_anywhere':
        'You told us you want to feel confident wherever you go. That’s '
        'exactly what we’re building toward.',
    'found_my_look':
        'You told us you want to finally find your look. That’s exactly what '
        'we’re building toward.',
    'excited_not_stressed':
        'You told us you want getting dressed to feel exciting, not '
        'stressful. That’s exactly what we’re building toward.',
    'proud_no_second_guessing':
        'You told us you want to show up without second-guessing. That’s '
        'exactly what we’re building toward.',
  };

  /// Swatches per palette (step 5), for a blueprint without a skin shade.
  static const _paletteSwatches = <String, List<Color>>{
    'neutrals': [Color(0xFF1C1A19), Color(0xFF807B77), Color(0xFFF5F0EA)],
    'earth_tones': [Color(0xFF6B4530), Color(0xFFC89E78), Color(0xFF636F48)],
    'jewel_tones': [Color(0xFF1E2E4A), Color(0xFF1D503E), Color(0xFF652233)],
    'pastels': [Color(0xFFE8B8B8), Color(0xFFB6CCE2), Color(0xFFD4E2C8)],
    'black_white': [Color(0xFF121110), Color(0xFFFFFFFF), Color(0xFF555350)],
    'bold_bright': [Color(0xFF1E40AF), Color(0xFFE59E18), Color(0xFFDC2626)],
  };

  /// Headline from the top two aesthetics; a neutral phrase without them (a
  /// resumed session that skipped ahead).
  String _headline(StyleBlueprintDraft b) {
    final names = [
      for (final a in b.styleAesthetics.take(2)) _aesthetics[a] ?? a,
    ];
    if (names.isEmpty) return 'Your Style, Defined';
    return '${names.join(', ')},\nWorn with Confidence';
  }

  /// Five colours: those that flatter the skin shade; without one (step 4
  /// skipped), from the palettes picked at step 5; else the brand's tones.
  List<Color> _palette(StyleBlueprintDraft b) {
    if (skinShade(b.skinShade) case final shade?) return shade.flattering;
    final colors = [for (final p in b.colorPalettes) ...?_paletteSwatches[p]];
    if (colors.isEmpty) {
      return const [
        Color(0xFF2A1810),
        Color(0xFF6B4530),
        Color(0xFF8B9E6E),
        Color(0xFFD4C0B0),
        Color(0xFFF5E8D8),
      ];
    }
    return colors.take(5).toList();
  }

  String _paletteNote(StyleBlueprintDraft b) {
    final tone = b.skinShade == null ? null : 'Tone ${b.skinShade}';
    final under = _undertones[b.undertone];
    if (tone != null && under != null) {
      return 'Tailored to $tone · $under undertone';
    }
    if (tone != null) return 'Tailored to $tone';
    if (under != null) {
      return 'Tailored to your ${under.toLowerCase()} undertone';
    }
    if (b.colorPalettes.isNotEmpty) return 'From the colours you gravitate to';
    return 'A warm starting palette';
  }

  /// The snapshot: aesthetics, body shape, skin tone and dress code.
  List<String> _tags(StyleBlueprintDraft b) {
    final tone = [
      if (b.skinShade != null) 'Tone ${b.skinShade}',
      ?_undertones[b.undertone],
    ].join(' · ');
    return [
      for (final a in b.styleAesthetics) _aesthetics[a] ?? a,
      ?bodyShapeLabel(b.bodyShape, state.shoppingStyle),
      if (tone.isNotEmpty) tone,
      ?_dressCodes[b.dressCode],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final b = state.blueprint;
    final body = BlueprintText.optionSupport(context);
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.ivoryHigh,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 20,
                    color: AppColors.espressoDark,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Eyebrow(),
              const SizedBox(height: 8),
              Text(
                _headline(b),
                textAlign: TextAlign.center,
                style: BlueprintText.heading(context).copyWith(
                  fontSize: 32,
                  height: 1.18,
                  color: AppColors.espressoDark,
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Text(
                    _feelingLines[b.threeMonthFeelings.firstOrNull] ??
                        'Here’s what we learned about how you want to dress.',
                    textAlign: TextAlign.center,
                    style: body.copyWith(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              const _Moodboard(),
              const SizedBox(height: 24),
              _PaletteFan(colors: _palette(b)),
              const SizedBox(height: 8),
              Text(
                'YOUR PALETTE',
                textAlign: TextAlign.center,
                style: body.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: AppColors.taupe,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _paletteNote(b),
                textAlign: TextAlign.center,
                style: body.copyWith(
                  fontSize: 11,
                  color: AppColors.inkSoft.withValues(alpha: 0.8),
                ),
              ),
              const SizedBox(height: 28),
              _Snapshot(tags: _tags(b), onEdit: onEdit),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            children: [
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: submitting ? null : onBuildWardrobe,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.espresso,
                    disabledBackgroundColor: AppColors.taupeSoft,
                    foregroundColor: AppColors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(AppColors.white),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                'Build My Wardrobe',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: AppColors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 8),
              const PipedaNote(),
            ],
          ),
        ),
      ],
    );
  }
}

class _Moodboard extends StatelessWidget {
  const _Moodboard();

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 144,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/onboarding/atelier_moodboard.jpg',
              fit: BoxFit.cover,
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppColors.white.withValues(alpha: 0.9),
                    AppColors.white.withValues(alpha: 0.2),
                    AppColors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Atelier Moodboard 01',
                          style: BlueprintText.heading(context).copyWith(
                            fontSize: 14,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 0,
                            color: AppColors.espressoDark,
                          ),
                        ),
                        Text(
                          'Textural harmony · Quiet warmth',
                          style: body.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: AppColors.inkSoft,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.sage,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'MATCHED',
                          style: body.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                            color: AppColors.espressoDark,
                          ),
                        ),
                      ],
                    ),
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

/// Five overlapping swatches, each ringed in white.
class _PaletteFan extends StatelessWidget {
  const _PaletteFan({required this.colors});

  final List<Color> colors;

  static const _size = 36.0;
  static const _overlap = 10.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: colors.length * _size - (colors.length - 1) * _overlap + 4,
        height: _size + 8,
        child: Stack(
          children: [
            for (final (i, c) in colors.indexed)
              Positioned(
                left: 2 + i * (_size - _overlap),
                top: 2,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x262A1810),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "Atelier Profile Snapshot": the blueprint's headline answers as tags,
/// with Edit to change them.
class _Snapshot extends StatelessWidget {
  const _Snapshot({required this.tags, required this.onEdit});

  final List<String> tags;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F6B4530),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 14, color: AppColors.taupe),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'ATELIER PROFILE SNAPSHOT',
                  style: body.copyWith(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.taupe,
                  ),
                ),
              ),
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Edit',
                        style: body.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.espressoDark,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.edit_outlined,
                        size: 12,
                        color: AppColors.espressoDark,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in tags)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.ivoryWarm,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    t,
                    style: body.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.espressoDark,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Failed ───────────────────────────────────────────────────────────────

class _Failed extends StatefulWidget {
  const _Failed({
    required this.recorded,
    required this.onRetry,
    required this.onResume,
  });

  /// How many of the steps' answers have reached the backend.
  final int recorded;
  final Future<void> Function() onRetry;
  final VoidCallback onResume;

  @override
  State<_Failed> createState() => _FailedState();
}

class _FailedState extends State<_Failed> with SingleTickerProviderStateMixin {
  late final AnimationController _halo = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = BlueprintText.optionSupport(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      children: [
        const _Eyebrow(color: AppColors.taglineGrey, spacing: 1.5),
        const SizedBox(height: 32),
        SizedBox(
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              FadeTransition(
                opacity: Tween(begin: 0.4, end: 1.0).animate(_halo),
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.ivoryHigh.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppColors.sand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  size: 24,
                  color: AppColors.espresso,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: Text(
              'We couldn’t build your blueprint just now.',
              textAlign: TextAlign.center,
              style: BlueprintText.heading(context).copyWith(fontSize: 24),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              'Your answers are saved. A brief connection hiccup interrupted '
              'synthesis, but nothing has been lost.',
              textAlign: TextAlign.center,
              style: body.copyWith(
                fontSize: 13,
                height: 1.6,
                color: AppColors.inkSoft,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 280),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ivoryDim,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D000000),
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.sand,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 18,
                    color: AppColors.espresso,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${widget.recorded} of $kBlueprintSteps inputs '
                              'recorded',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: body.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.ink,
                              ),
                            ),
                          ),
                          Text(
                            'Saved',
                            style: body.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                              color: AppColors.sage,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Palette, silhouette & climate intact',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: body.copyWith(
                          fontSize: 11,
                          color: AppColors.inkSoft.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 240),
            child: SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.sync, size: 16),
                label: Text(
                  'Try Again',
                  style: body.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: AppColors.white,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.espresso,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: widget.onResume,
            child: Text(
              'Resume from Step $kBlueprintSteps',
              style: body.copyWith(
                fontSize: 12,
                color: AppColors.inkSoft,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.taupeSoft,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const PipedaNote(),
      ],
    );
  }
}
