import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';

/// Horizontal, card-snapping carousel for Today's outfits. The next card peeks
/// in from the right so it reads as swipeable; every card is stretched to the
/// tallest one so the CTA rows line up (children get a bounded height, so an
/// `OutfitCard(expand: true)` may fill it). A lone card takes the full width.
/// With more than one card, page dots under the row show which one is in
/// view (tap one to go to it).
class OutfitCarousel extends StatefulWidget {
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
  State<OutfitCarousel> createState() => _OutfitCarouselState();
}

class _OutfitCarouselState extends State<OutfitCarousel> {
  final _controller = ScrollController();

  /// Card extent (width + gap) from the last layout, for the page index.
  double _extent = 1;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    final last = math.max(0, widget.children.length - 1);
    final position = _controller.position;
    // At the end of the row the last card is in view, even when the row
    // can't scroll a whole card further (wide screens, capped card width).
    final page = position.pixels >= position.maxScrollExtent - 1
        ? last
        : (position.pixels / _extent).round().clamp(0, last);
    if (page != _page) setState(() => _page = page);
  }

  void _goTo(int page) {
    if (!_controller.hasClients) return;
    _controller.animateTo(
      (page * _extent).clamp(0, _controller.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final children = widget.children;
    if (children.isEmpty) return const SizedBox.shrink();
    final gutter = widget.gutter;
    final gap = widget.gap;
    final single = children.length == 1;
    final page = math.min(_page, children.length - 1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = single
            ? width - gutter * 2
            : math.min(width - gutter - gap - widget.peek, 380.0);
        _extent = cardWidth + gap;
        final row = SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          physics: single
              ? const NeverScrollableScrollPhysics()
              : _CardSnapPhysics(itemExtent: cardWidth + gap),
          padding: EdgeInsets.symmetric(horizontal: gutter),
          // Room for the cards' ambient shadow, which the scroll view clips.
          child: Padding(
            padding: EdgeInsets.only(top: 4, bottom: single ? 20 : 12),
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
        if (single) return row;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            row,
            _PageDots(count: children.length, current: page, onTap: _goTo),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

/// "● ○ ○" under the carousel: the card in view is a wider espresso pill.
class _PageDots extends StatelessWidget {
  final int count;
  final int current;
  final ValueChanged<int> onTap;

  const _PageDots({
    required this.count,
    required this.current,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Look ${current + 1} of $count',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < count; i++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onTap(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == current ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.espresso
                        : AppColors.taupeSoft,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
        ],
      ),
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
