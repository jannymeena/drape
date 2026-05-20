import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

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
        DrapeButton.apple(label: 'Continue with Apple', onPressed: onApple),
        const SizedBox(height: 12),
        DrapeButton.google(label: 'Continue with Google', onPressed: onGoogle),
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
