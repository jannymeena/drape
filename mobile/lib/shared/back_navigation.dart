import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Passed as `extra` to `go`/`goNamed` when the jump is really a step *back*
/// (e.g. Back on a resumed step that has nothing underneath to pop).
///
/// `go` replaces the stack, so by default it plays the forward animation.
/// Routes built with [slidePage] check for this and slide the page in from
/// the left instead, so it reads as going back.
class BackNavigation {
  const BackNavigation();
}

const goingBack = BackNavigation();

/// A route page that uses the app's page transition (a horizontal slide,
/// see `AppTheme`) for forward navigation, and slides in from the left when
/// reached with `extra: goingBack`.
Page<void> slidePage(GoRouterState state, Widget child) {
  if (state.extra is! BackNavigation) {
    return MaterialPage<void>(key: state.pageKey, child: child);
  }
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    // Matches the Cupertino-style slide used for push and pop.
    transitionDuration: const Duration(milliseconds: 500),
    reverseTransitionDuration: const Duration(milliseconds: 500),
    transitionsBuilder: (_, animation, _, child) => SlideTransition(
      position: Tween<Offset>(begin: const Offset(-1, 0), end: Offset.zero)
          .animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.fastLinearToSlowEaseIn,
              reverseCurve: Curves.fastLinearToSlowEaseIn.flipped,
            ),
          ),
      child: child,
    ),
  );
}
