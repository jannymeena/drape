import 'package:flutter/material.dart';

import 'outfit_card.dart';
import 'outfit_card_skeleton.dart';

/// [child] at exactly an outfit card's size, so a stand-in card (plan today,
/// add items) keeps the carousel's height when the looks replace it.
///
/// Sizes itself on an invisible [OutfitCardSkeleton] (which mirrors
/// [OutfitCard]'s layout) and lays [child] over it.
class OutfitCardSized extends StatelessWidget {
  final Widget child;

  const OutfitCardSized({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Sizing only — hidden, and its shimmer doesn't tick.
        const TickerMode(
          enabled: false,
          child: Visibility(
            visible: false,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: OutfitCardSkeleton(),
          ),
        ),
        Positioned.fill(child: child),
      ],
    );
  }
}
