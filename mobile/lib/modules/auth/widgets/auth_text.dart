import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// The one type scale for the auth screens (login, sign-up).
///
/// The two designs specified their headings differently — login as a 32px
/// serif page heading in the body, sign-up as a 24px sans title in the app bar
/// — so the pair read as two different screens rather than two steps of one
/// flow. Both now use [heading], and everything else on the screens pulls from
/// here rather than reaching into `Theme.of(context).textTheme` directly, so
/// the scale can only change in one place.
class AuthText {
  AuthText._();

  /// The page heading: "Welcome back", "Create Account". 32sp serif.
  static TextStyle heading(BuildContext context) =>
      Theme.of(context).textTheme.headlineLarge!;

  /// The explanatory line under a heading, when a screen has one. 16sp.
  static TextStyle subheading(BuildContext context) =>
      Theme.of(context).textTheme.bodyLarge!.copyWith(
            height: 1.5,
            color: AppColors.inkSoft,
          );

  /// The label inside a primary or SSO button. 16sp semibold.
  static TextStyle button(BuildContext context) =>
      Theme.of(context).textTheme.titleMedium!;

  /// The "or" between the SSO block and the email form. 12sp.
  static TextStyle divider(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!.copyWith(color: AppColors.taupe);

  /// Fine print: the PIPEDA line, the terms sentence, "Forgot password?". 12sp.
  static TextStyle legal(BuildContext context) =>
      Theme.of(context).textTheme.bodySmall!;

  /// The bottom "No account? / Already have an account?" line. 14sp.
  static TextStyle footer(BuildContext context) =>
      Theme.of(context).textTheme.bodyMedium!;

  /// The tappable half of a [footer] line or a legal sentence.
  static const TextStyle link = TextStyle(
    color: AppColors.ink,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );
}
