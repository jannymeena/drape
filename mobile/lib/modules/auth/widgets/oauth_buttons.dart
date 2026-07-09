import 'package:flutter/material.dart';

import '../../../shared/config/feature_flags.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// The Apple/Google sign-in block. Each button renders only when its feature
/// switch is on ([FeatureFlags.appleLogin] / [FeatureFlags.googleLogin]); with
/// both off the whole block — divider included — collapses, so email-only
/// builds show no dead controls.
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
    final buttons = <Widget>[
      if (FeatureFlags.appleLogin)
        DrapeButton.apple(label: 'Continue with Apple', onPressed: onApple),
      if (FeatureFlags.googleLogin)
        DrapeButton.google(label: 'Continue with Google', onPressed: onGoogle),
    ];
    if (buttons.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (final (i, button) in buttons.indexed) ...[
          if (i > 0) const SizedBox(height: 12),
          button,
        ],
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
          child: Text(
            'or',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.taupe,
                ),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.taupeSoft, thickness: 1)),
      ],
    );
  }
}
