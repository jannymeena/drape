import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Horizontal, card-snapping carousel for Today's outfits. The next card peeks
/// in from the right so it reads as swipeable; every card is stretched to the
/// tallest one so the CTA rows line up (children get a bounded height, so an
/// `OutfitCard(expand: true)` may fill it). A lone card takes the full width.
class OutfitCarousel extends StatelessWidget {
  final List<Widget> children;

  /// Outer padding — matches the page gutter so the first card lines up with
  /// the content above it while the row itself scrolls edge to edge.
  final double gutter;
  final double gap;

  /// How much of the next card shows (plus [gap]).
  final double peek;

  const OutfitCarousel({
    super.key,
    required this.children,
    this.gutter = 16,
    this.gap = 16,
    this.peek = 32,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final single = children.length == 1;
        final cardWidth = single
            ? width - gutter * 2
            : math.min(width - gutter - gap - peek, 380.0);
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: single
              ? const NeverScrollableScrollPhysics()
              : _CardSnapPhysics(itemExtent: cardWidth + gap),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          // Room for the cards' ambient shadow, which the scroll view clips.
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 20),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (i, child) in children.indexed) ...[
                    if (i > 0) SizedBox(width: gap),
                    SizedBox(width: cardWidth, child: child),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Settles on the nearest card edge; a fling moves at least one card.
class _CardSnapPhysics extends ScrollPhysics {
  final double itemExtent;
  const _CardSnapPhysics({required this.itemExtent, super.parent});

  @override
  _CardSnapPhysics applyTo(ScrollPhysics? ancestor) =>
      _CardSnapPhysics(itemExtent: itemExtent, parent: buildParent(ancestor));

  double _target(ScrollMetrics position, Tolerance tolerance, double velocity) {
    var page = position.pixels / itemExtent;
    if (velocity < -tolerance.velocity) {
      page -= 0.5;
    } else if (velocity > tolerance.velocity) {
      page += 0.5;
    }
    return (page.roundToDouble() * itemExtent)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }
    final tolerance = toleranceFor(position);
    final target = _target(position, tolerance, velocity);
    if (target != position.pixels) {
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        target,
        velocity,
        tolerance: tolerance,
      );
    }
    return null;
  }

  @override
  bool get allowImplicitScrolling => false;
}
