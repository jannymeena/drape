import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Headlines + display use Cormorant Garamond (serif).
/// Titles, body, and labels use DM Sans (sans-serif).
/// On first launch google_fonts fetches webfonts; subsequent launches use cache.
class AppTypography {
  AppTypography._();

  static TextStyle _serif({
    required double size,
    FontWeight weight = FontWeight.w600,
    double? height,
    double? letterSpacing,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.cormorantGaramond(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextStyle _sans({
    required double size,
    FontWeight weight = FontWeight.w400,
    double? height,
    double? letterSpacing,
    Color color = AppColors.ink,
  }) {
    return GoogleFonts.dmSans(
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
      color: color,
    );
  }

  static TextTheme get textTheme => TextTheme(
        // Display (large brand moments — splash, welcome)
        displayLarge: _serif(size: 57, height: 1.12),
        displayMedium: _serif(size: 45, height: 1.15),
        displaySmall: _serif(size: 36, height: 1.20),

        // Headlines (screen titles like "Welcome back", "What style do you shop for?")
        headlineLarge: _serif(size: 32, height: 1.25),
        headlineMedium: _serif(size: 28, height: 1.28),
        headlineSmall: _serif(size: 24, height: 1.30),

        // Titles (section labels, card titles)
        titleLarge: _sans(size: 22, weight: FontWeight.w600, height: 1.27),
        titleMedium: _sans(size: 16, weight: FontWeight.w600, height: 1.50),
        titleSmall: _sans(size: 14, weight: FontWeight.w600, height: 1.43),

        // Body
        bodyLarge: _sans(size: 16, height: 1.50),
        bodyMedium: _sans(
          size: 14,
          height: 1.43,
          color: AppColors.inkSoft,
        ),
        bodySmall: _sans(
          size: 12,
          height: 1.33,
          color: AppColors.inkSoft,
        ),

        // Labels (buttons, chips, badges)
        labelLarge: _sans(size: 14, weight: FontWeight.w600, height: 1.43),
        labelMedium: _sans(size: 12, weight: FontWeight.w600, height: 1.33),
        labelSmall: _sans(
          size: 11,
          weight: FontWeight.w600,
          height: 1.45,
          letterSpacing: 1.2,
        ),
      );

  /// Newsreader — the Today tab's editorial serif (Stitch `font-headline`).
  static TextStyle _newsreader({
    required double size,
    FontWeight weight = FontWeight.w600,
    double height = 1.25,
    double? letterSpacing,
  }) =>
      GoogleFonts.newsreader(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        color: AppColors.espressoDark,
      );

  /// Today's "Good morning, …" greeting, as the Stitch Today mock sets it:
  /// 30 (`text-3xl`), semibold, tracking-tight (-0.025em), leading-tight.
  static TextStyle get greeting =>
      _newsreader(size: 30, letterSpacing: -0.75);

  /// Today's card + section titles ("Work look", "Shop the look"): the
  /// mock's `text-2xl font-semibold tracking-tight` — 24, semibold, -0.025em.
  static TextStyle get sectionTitle =>
      _newsreader(size: 24, letterSpacing: -0.6);

  /// Pushed Today screens' centred title ("Plan your week"): 24, semibold,
  /// leading-tight — same face as the greeting.
  static TextStyle get screenTitle => _newsreader(size: 24);

  /// Splash-screen wordmark style (ZOURA, 48dp, wide tracking).
  static TextStyle get brandMark => _serif(
        size: 48,
        weight: FontWeight.w600,
        letterSpacing: 8,
        color: AppColors.brandText,
      );

  /// Splash tagline ("Your personal stylist.").
  static TextStyle get tagline => _sans(
        size: 14,
        letterSpacing: 0.7,
        color: AppColors.taglineGrey,
      );
}
