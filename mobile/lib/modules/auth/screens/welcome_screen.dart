import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import 'login_screen.dart';
import 'sign_up_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  static const path = '/';
  static const name = 'welcome';

  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final _controller = PageController();
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _trackSlide(0);
  }

  void _trackSlide(int index) {
    ref
        .read(analyticsProvider)
        .capture(AnalyticsEvents.welcomeSlideViewed, {'slide_number': index + 1});
  }

  static const _slides = [
    _Slide(
      heroKind: _HeroKind.flatLay,
      image: 'assets/onboarding/welcome_flat_lay.png',
      backdrop: Color(0xFFEEE0CD), // sampled from the flat-lay's own background
      title: 'You already own the\nperfect outfit.',
      subtitle: 'DRAPE finds it every morning.',
      cta: 'Get Started',
    ),
    _Slide(
      heroKind: _HeroKind.scanning,
      backdrop: Color(0xFFFDF2E8), // warm peach scan backdrop from the handoff
      title: 'Scan. Tag. Done.',
      subtitle: "Point at any item and we'll handle the rest. No typing, no tagging.",
      cta: 'Next',
    ),
    _Slide(
      heroKind: _HeroKind.outfitCard,
      backdrop: Color(0xFFFDF2E8), // warm peach backdrop from the handoff
      title: 'Every morning. 10\nseconds. Done.',
      subtitle: 'Your AI stylist, powered by your actual wardrobe.',
      cta: 'Create My Account',
    ),
  ];

  bool get _isLast => _index == _slides.length - 1;

  void _onPrimary() {
    if (_isLast) {
      context.goNamed(SignUpScreen.name);
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onSkip() {
    ref
        .read(analyticsProvider)
        .capture(AnalyticsEvents.welcomeSkipped, {'slide_number': _index + 1});
    context.goNamed(SignUpScreen.name);
  }
  void _onSignIn() => context.goNamed(LoginScreen.name);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top bar: brand mark + Skip (hidden on last slide)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'DRAPE',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w400,
                          letterSpacing: 3,
                          color: AppColors.espressoDark,
                        ),
                  ),
                  // Always laid out (hidden on the last slide) so the top bar
                  // height — and everything below it — stays put across slides.
                  Visibility(
                    visible: !_isLast,
                    maintainSize: true,
                    maintainAnimation: true,
                    maintainState: true,
                    child: TextButton(
                      onPressed: _onSkip,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.taupe,
                      ),
                      child: Text(
                        'SKIP',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              letterSpacing: 1.2,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Hero (top ~50%)
            Expanded(
              flex: 5,
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _trackSlide(i);
                },
                itemBuilder: (_, i) => _Hero(slide: _slides[i]),
              ),
            ),

            // Caption + CTA zone — fixed height so the dots, title and button
            // keep the same position on every slide (only the hero above
            // resizes, per device). The Spacer lets the title grow downward
            // without nudging the CTA, and the Sign-In row is always reserved.
            SizedBox(
              height: 340,
              child: Column(
                children: [
                  // Dots
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _slides.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: i == _index ? 10 : 8,
                          height: i == _index ? 10 : 8,
                          decoration: BoxDecoration(
                            color: i == _index ? AppColors.espresso : AppColors.taupeSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Title + subtitle (top-aligned; grows into the Spacer below)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        Text(
                          _slides[_index].title,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                height: 1.1,
                                letterSpacing: -0.5,
                                color: AppColors.ink,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _slides[_index].subtitle,
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: AppColors.inkSoft,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // CTA cluster — bottom-pinned
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: Column(
                      children: [
                        DrapeButton(
                          label: _slides[_index].cta,
                          onPressed: _onPrimary,
                          pill: true,
                          elevation: 6,
                          labelStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                          trailing: const Icon(
                            Icons.arrow_forward,
                            color: AppColors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Always laid out (only shown on the last slide) so the
                        // button keeps the same position across slides.
                        Visibility(
                          visible: _isLast,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: TextButton(
                            onPressed: _onSignIn,
                            child: Text.rich(
                              TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium,
                                children: const [
                                  TextSpan(text: 'Already have an account? '),
                                  TextSpan(
                                    text: 'Sign In',
                                    style: TextStyle(
                                      color: AppColors.ink,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _HeroKind { flatLay, scanning, outfitCard }

class _Slide {
  final _HeroKind heroKind;

  /// Real hero artwork; falls back to the [heroKind] placeholder mock when null.
  final String? image;

  /// Hero card background; defaults to [AppColors.ivoryWarm] when null.
  final Color? backdrop;
  final String title;
  final String subtitle;
  final String cta;

  const _Slide({
    required this.heroKind,
    this.image,
    this.backdrop,
    required this.title,
    required this.subtitle,
    required this.cta,
  });
}

/// Hero artwork zone. Renders the slide's [image] when present (on its sampled
/// [backdrop] so the surround blends seamlessly); otherwise a placeholder mock.
class _Hero extends StatelessWidget {
  final _Slide slide;
  const _Hero({required this.slide});

  @override
  Widget build(BuildContext context) {
    final hasImage = slide.image != null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: slide.backdrop ?? AppColors.ivoryWarm,
          alignment: Alignment.center,
          child: hasImage
              ? Image.asset(slide.image!, fit: BoxFit.contain)
              : switch (slide.heroKind) {
                  _HeroKind.flatLay => const _FlatLayMock(),
                  _HeroKind.scanning => const _ScanningMock(),
                  _HeroKind.outfitCard => const _OutfitCardMock(),
                },
        ),
      ),
    );
  }
}

class _FlatLayMock extends StatelessWidget {
  const _FlatLayMock();
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      padding: const EdgeInsets.all(28),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: List.generate(
        9,
        (i) => Container(
          decoration: BoxDecoration(
            color: i % 2 == 0 ? AppColors.tan : AppColors.sand,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}

/// Phone "scanning" mock: the real shirt photo inside a phone viewfinder, with
/// a targeting reticle and an AI classification badge, per the slide-2 handoff.
class _ScanningMock extends StatelessWidget {
  const _ScanningMock();

  static const _bezel = Color(0xFF31302D); // phone frame edge

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: Container(
          width: 184,
          height: 360,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppColors.espressoDeep,
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: _bezel, width: 6),
            boxShadow: const [
              BoxShadow(color: Color(0x40000000), blurRadius: 24, offset: Offset(0, 12)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Viewfinder: the scanned shirt over an ivory ground.
                const Positioned.fill(child: ColoredBox(color: AppColors.ivory)),
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.8,
                    child: Image.asset(
                      'assets/onboarding/welcome_scan.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // Targeting reticle.
                const _ScanReticle(),
                // AI classification badge.
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, color: AppColors.sage, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        'Oxford Shirt · Casual',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.espressoDark,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// White targeting square with brighter bracketed corners.
class _ScanReticle extends StatelessWidget {
  const _ScanReticle();

  @override
  Widget build(BuildContext context) {
    const bracket = BorderSide(color: AppColors.white, width: 2);
    Widget corner(Border border) =>
        Container(width: 16, height: 16, decoration: BoxDecoration(border: border));

    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white70, width: 2),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Positioned(top: -1, left: -1, child: corner(const Border(top: bracket, left: bracket))),
          Positioned(top: -1, right: -1, child: corner(const Border(top: bracket, right: bracket))),
          Positioned(bottom: -1, left: -1, child: corner(const Border(bottom: bracket, left: bracket))),
          Positioned(bottom: -1, right: -1, child: corner(const Border(bottom: bracket, right: bracket))),
        ],
      ),
    );
  }
}

/// Floating "outfit of the day" recommendation card: weather/occasion pills,
/// the real outfit image on an ivory ground, and the AI rationale caption.
class _OutfitCardMock extends StatelessWidget {
  const _OutfitCardMock();

  static const _pillBg = Color(0xFFF5E8D8);
  static const _captionColor = Color(0xFF6B5848);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: 300,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x142A1810), blurRadius: 48, offset: Offset(0, 24)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    _Pill(label: '☀ 14°C', bg: _pillBg, fg: AppColors.espresso),
                    SizedBox(width: 8),
                    _Pill(label: 'Casual', bg: _pillBg, fg: AppColors.espresso),
                  ],
                ),
                const SizedBox(height: 16),
                AspectRatio(
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: ColoredBox(
                      color: AppColors.ivory,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Opacity(
                          opacity: 0.9,
                          child: Image.asset(
                            'assets/onboarding/welcome_outfit.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Why DRAPE picked this: relaxed day, "
                  "you haven't worn the blazer in 2 weeks.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: _captionColor,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  const _Pill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
      ),
    );
  }
}
