import 'package:flutter/material.dart';

/// Swipe between onboarding screens: a swipe right calls [onBack], a swipe
/// left calls [onForward]. Either can be null to switch that direction off
/// (e.g. forward while the step's required answers are missing).
///
/// The swipe only triggers the same navigation as the buttons, so the page
/// change uses the usual slide. Sliders and horizontal lists inside the page
/// keep their own drags: they're deeper in the tree, so they claim the
/// gesture first.
class StepSwipe extends StatefulWidget {
  const StepSwipe({
    super.key,
    required this.child,
    this.onBack,
    this.onForward,
  });

  final Widget child;
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  @override
  State<StepSwipe> createState() => _StepSwipeState();
}

class _StepSwipeState extends State<StepSwipe> {
  /// How far, or how fast, a drag has to go to count as a swipe.
  static const _minDistance = 80.0;
  static const _minVelocity = 600.0;

  double _dx = 0;

  void _end(DragEndDetails details) {
    final v = details.primaryVelocity ?? 0;
    final dx = _dx;
    _dx = 0;
    // Only the top screen reacts: a second swipe mid-transition must not
    // act on the screen that's already on its way out.
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) return;
    final right = dx > _minDistance || v > _minVelocity;
    final left = dx < -_minDistance || v < -_minVelocity;
    if (right && !left) {
      widget.onBack?.call();
    } else if (left && !right) {
      widget.onForward?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Always in the tree, even with both directions off: adding it later
    // would rebuild the page under it (losing its scroll position).
    return GestureDetector(
      // Catch swipes that start on the page's empty space too.
      behavior: HitTestBehavior.translucent,
      onHorizontalDragStart: (_) => _dx = 0,
      onHorizontalDragUpdate: (d) => _dx += d.primaryDelta ?? 0,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => _dx = 0,
      child: widget.child,
    );
  }
}
