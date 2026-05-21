import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Shown on the Buy/Don't Buy scan screen when the free user is near the
/// weekly limit (e.g. 4/5 used → "1 check left").
class BuyDontBuyUsageBanner extends StatelessWidget {
  final int checksLeft;
  final VoidCallback onUpgrade;

  const BuyDontBuyUsageBanner({
    super.key,
    required this.checksLeft,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8EC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFC8901C), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF7D5A11),
                    ),
                children: [
                  TextSpan(
                    text:
                        '$checksLeft check${checksLeft == 1 ? '' : 's'} left this week. Resets Monday 5 AM. ',
                  ),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: GestureDetector(
                      onTap: onUpgrade,
                      child: Text(
                        'Upgrade for unlimited →',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.espresso,
                              fontWeight: FontWeight.w700,
                              decoration: TextDecoration.underline,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
