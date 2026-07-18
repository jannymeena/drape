import 'package:flutter/material.dart';

import '../shared/theme/app_colors.dart';
import '../shared/theme/app_typography.dart';
import '../shared/widgets/drape_app_bar.dart';
import '../shared/widgets/drape_bottom_nav.dart';
import '../shared/widgets/drape_button.dart';
import '../shared/widgets/drape_text_field.dart';
import '../shared/widgets/occasion_badge.dart';
import '../shared/widgets/outline_chip.dart';
import '../shared/widgets/shimmer_skeleton.dart';

class ThemeGalleryScreen extends StatefulWidget {
  static const path = '/debug/theme';
  static const name = 'theme_gallery';

  const ThemeGalleryScreen({super.key});

  @override
  State<ThemeGalleryScreen> createState() => _ThemeGalleryScreenState();
}

class _ThemeGalleryScreenState extends State<ThemeGalleryScreen> {
  DrapeNavDestination _nav = DrapeNavDestination.today;
  bool _chipSelected = true;
  final _emailController = TextEditingController(text: 'kugan@example.com');
  final _passwordController = TextEditingController(text: 'secret123');

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const DrapeAppBar(title: 'Theme Gallery', showBack: false),
      bottomNavigationBar: DrapeBottomNav(
        current: _nav,
        onSelected: (n) => setState(() => _nav = n),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          // ─── Splash mark (the only dark surface in the app) ───
          _Section(
            title: 'Brand mark',
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              decoration: BoxDecoration(
                color: AppColors.espressoDeep,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('ZOURA', style: AppTypography.brandMark),
                  const SizedBox(height: 8),
                  Text('Your personal stylist.', style: AppTypography.tagline),
                ],
              ),
            ),
          ),

          // ─── Color swatches ───
          _Section(
            title: 'Palette',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                _Swatch('primary', AppColors.espresso, AppColors.white),
                _Swatch('primaryDark', AppColors.espressoDark, AppColors.white),
                _Swatch('espressoDeep', AppColors.espressoDeep, AppColors.brandText),
                _Swatch('tan', AppColors.tan, AppColors.ink),
                _Swatch('sage', AppColors.sage, AppColors.white),
                _Swatch('sageDim', AppColors.sageDim, AppColors.ink),
                _Swatch('gold', AppColors.gold, AppColors.ink),
                _Swatch('ivory', AppColors.ivory, AppColors.ink),
                _Swatch('ivoryWarm', AppColors.ivoryWarm, AppColors.ink),
                _Swatch('sand', AppColors.sand, AppColors.ink),
                _Swatch('taupe', AppColors.taupe, AppColors.white),
                _Swatch('ink', AppColors.ink, AppColors.white),
                _Swatch('inkSoft', AppColors.inkSoft, AppColors.white),
                _Swatch('error', AppColors.error, AppColors.white),
              ],
            ),
          ),

          // ─── Typography ───
          _Section(
            title: 'Typography',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Display Large', style: Theme.of(context).textTheme.displayLarge),
                Text('Display Medium', style: Theme.of(context).textTheme.displayMedium),
                Text('Headline Large', style: Theme.of(context).textTheme.headlineLarge),
                Text('Headline Medium', style: Theme.of(context).textTheme.headlineMedium),
                Text('Headline Small', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text('Title Large', style: Theme.of(context).textTheme.titleLarge),
                Text('Title Medium', style: Theme.of(context).textTheme.titleMedium),
                Text('Title Small', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('Body Large — DM Sans 16. The quick brown fox.',
                    style: Theme.of(context).textTheme.bodyLarge),
                Text('Body Medium — DM Sans 14. Subdued.',
                    style: Theme.of(context).textTheme.bodyMedium),
                Text('Body Small — DM Sans 12.',
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 8),
                Text('Label Large', style: Theme.of(context).textTheme.labelLarge),
                Text('Label Medium', style: Theme.of(context).textTheme.labelMedium),
                Text('LABEL SMALL', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),

          // ─── Buttons ───
          _Section(
            title: 'Buttons',
            child: Column(
              children: [
                DrapeButton(label: 'Create Account', onPressed: () {}),
                const SizedBox(height: 12),
                DrapeButton.apple(label: 'Continue with Apple', onPressed: () {}),
                const SizedBox(height: 12),
                DrapeButton.google(label: 'Continue with Google', onPressed: () {}),
                const SizedBox(height: 12),
                DrapeButton.outlined(label: 'Skip for now', onPressed: () {}),
                const SizedBox(height: 12),
                DrapeButton(label: 'Loading…', onPressed: () {}, loading: true),
                const SizedBox(height: 4),
                DrapeButton.text(label: 'Forgot password?', onPressed: () {}),
              ],
            ),
          ),

          // ─── Outline chips ───
          _Section(
            title: 'Outline chips',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlineChip(label: 'Casual', selected: _chipSelected, onPressed: () => setState(() => _chipSelected = !_chipSelected)),
                const OutlineChip(label: 'Work'),
                const OutlineChip(label: 'Gym'),
                const OutlineChip(label: 'Date'),
                const OutlineChip(label: 'History', icon: Icons.history),
                const OutlineChip(label: 'Mix & Match', icon: Icons.shuffle),
              ],
            ),
          ),

          // ─── Occasion badges ───
          _Section(
            title: 'Occasion badges',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: const [
                OccasionBadge(label: 'Work'),
                OccasionBadge(
                  label: 'Casual',
                  background: AppColors.sageDim,
                  foreground: AppColors.sageContent,
                ),
                OccasionBadge(
                  label: 'Evening',
                  background: AppColors.espresso,
                  foreground: AppColors.white,
                ),
                OccasionBadge(
                  label: 'Recommended',
                  background: AppColors.tanFixed,
                  foreground: AppColors.espressoDark,
                ),
              ],
            ),
          ),

          // ─── Text fields ───
          _Section(
            title: 'Text fields',
            child: Column(
              children: [
                DrapeTextField(
                  label: 'Email address',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DrapeTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                const DrapeTextField(
                  label: 'Email address',
                  errorText: 'Enter a valid email',
                ),
              ],
            ),
          ),

          // ─── Shimmer skeletons ───
          _Section(
            title: 'Shimmer skeletons',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerSkeleton(width: 160, height: 18),
                SizedBox(height: 8),
                ShimmerSkeleton(width: double.infinity, height: 12),
                SizedBox(height: 6),
                ShimmerSkeleton(width: double.infinity, height: 12),
                SizedBox(height: 16),
                ShimmerSkeleton(
                  width: double.infinity,
                  height: 120,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.inkSoft,
                  letterSpacing: 0.4,
                ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String name;
  final Color bg;
  final Color fg;
  const _Swatch(this.name, this.bg, this.fg);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 64,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.taupeSoft.withValues(alpha: 0.5)),
      ),
      alignment: Alignment.bottomLeft,
      child: Text(
        name,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
