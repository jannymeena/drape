import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// "Why this works" reasoning block embedded inside outfit cards on the
/// Today dashboard. Tap reveals the full AI reasoning detail screen.
class WhyThisWorksBlock extends StatelessWidget {
  final String reasoning;
  final VoidCallback? onLearnMore;

  const WhyThisWorksBlock({
    super.key,
    required this.reasoning,
    this.onLearnMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.tanFixed.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.lightbulb_outline,
                color: AppColors.espresso,
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'WHY THIS WORKS',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.espresso,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            reasoning,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (onLearnMore != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: onLearnMore,
                child: Text(
                  'LEARN MORE',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.espresso,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
