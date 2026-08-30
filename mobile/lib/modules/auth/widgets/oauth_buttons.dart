import 'package:flutter/material.dart';

import '../../../shared/config/feature_flags.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';
import 'auth_text.dart';

/// The Apple/Google sign-in block.
///
/// A provider whose feature switch is off ([FeatureFlags.appleLogin] /
/// [FeatureFlags.googleLogin]) renders **greyed out and inert** rather than
/// being removed, so the sign-in options a user sees don't change shape
/// between builds and platforms. (This reverses the earlier "off means hidden,
/// never shown dead" rule — see FeatureFlags — at the product owner's request.)
///
/// Note that the two switches mean different things: Google is off until its
/// client ID is configured, so it becomes available later; Apple is iOS-only,
/// so on Android its button is permanently inert.
class OAuthButtons extends StatelessWidget {
  final VoidCallback? onApple;
  final VoidCallback? onGoogle;
  final bool showDivider;

  const OAuthButtons({
    super.key,
    required this.onApple,
    required this.onGoogle,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DrapeButton.apple(
          label: 'Continue with Apple',
          labelStyle: AuthText.button(context),
          onPressed: FeatureFlags.appleLogin ? onApple : null,
        ),
        const SizedBox(height: 12),
        DrapeButton.google(
          label: 'Continue with Google',
          labelStyle: AuthText.button(context),
          onPressed: FeatureFlags.googleLogin ? onGoogle : null,
        ),
        if (showDivider) ...[
          const SizedBox(height: 20),
          const _OrDivider(),
          const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.taupeSoft, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: AuthText.divider(context)),
        ),
        const Expanded(child: Divider(color: AppColors.taupeSoft, thickness: 1)),
      ],
    );
  }
}
