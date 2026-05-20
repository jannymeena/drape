import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/drape_button.dart';

/// Returns true if the user confirmed skipping; false if they chose to continue.
Future<bool> showSkipConfirmationSheet(BuildContext context) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    backgroundColor: AppColors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _SkipConfirmationSheet(),
  );
  return result ?? false;
}

class _SkipConfirmationSheet extends StatelessWidget {
  const _SkipConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.tanFixed,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Text(
              "You can skip — but here's what you'll miss",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Column(
                    heading: 'WITHOUT AVATAR',
                    headingColor: AppColors.error,
                    bullets: const [
                      'Generic outfit sizing',
                      'Less accurate fits',
                      'No body-specific tips',
                    ],
                    isPositive: false,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _Column(
                    heading: 'WITH AVATAR',
                    headingColor: AppColors.sage,
                    bullets: const [
                      'Outfits match your build',
                      'Proportion-aware styling',
                      'Avatar shown in outfits',
                    ],
                    isPositive: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.ivoryWarm,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _Tile(color: AppColors.sand),
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.straighten, color: AppColors.sage, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          '98% ACCURACY',
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                color: AppColors.sage,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _Tile(color: AppColors.tan),
                ],
              ),
            ),
            const SizedBox(height: 20),
            DrapeButton.outlined(
              label: "Skip anyway, I'll do it later",
              onPressed: () => Navigator.pop(context, true),
            ),
            const SizedBox(height: 12),
            DrapeButton(
              label: "Let's build my avatar",
              onPressed: () => Navigator.pop(context, false),
            ),
          ],
        ),
      ),
    );
  }
}

class _Column extends StatelessWidget {
  final String heading;
  final Color headingColor;
  final List<String> bullets;
  final bool isPositive;
  const _Column({
    required this.heading,
    required this.headingColor,
    required this.bullets,
    required this.isPositive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          heading,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: headingColor,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        for (final b in bullets) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isPositive ? Icons.check : Icons.close,
                color: isPositive ? AppColors.sage : AppColors.error,
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  b,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  final Color color;
  const _Tile({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: AppColors.white, size: 28),
    );
  }
}
