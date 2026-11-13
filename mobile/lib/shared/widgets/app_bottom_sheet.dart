import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// The app's standard bottom-sheet modal (the "Plan a day" shell, made
/// general):
///
/// ```
/// ┌──────────────── ━━━━ ────────────────┐  grabber (always)
/// │            [title]                   │  fixed — optional
/// │ ┌──────────────────────────────────┐ │
/// │ │ child                            │ │  scrolls
/// │ └──────────────────────────────────┘ │
/// ├──────────────────────────────────────┤  border — [actionsBorder]
/// │ [actions]                            │  fixed footer — optional
/// └──────────────────────────────────────┘
/// ```
///
/// - As tall as its content, up to [heightFactor] of the screen (default
///   80%) — past that the body scrolls. Rounded top, ivory.
/// - Lifts above the keyboard; tapping blank space in the content closes it.
/// - No close button: drag it down or tap outside to dismiss.
///
/// Open it with [AppBottomSheet.show] (the matching scrim and modal
/// settings), and `Navigator.pop(context, result)` from inside to return a
/// value:
///
/// ```dart
/// final picked = await AppBottomSheet.show<String>(
///   context,
///   builder: (context) => AppBottomSheet(
///     title: 'Choose a size',
///     actions: FilledButton(
///       onPressed: () => Navigator.of(context).pop('done'),
///       child: const Text('Save'),
///     ),
///     child: const Text('Anything that should scroll'),
///   ),
/// );
/// ```
class AppBottomSheet extends StatelessWidget {
  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.actions,
    this.actionsBorder = true,
    this.heightFactor = 0.8,
    this.contentPadding = const EdgeInsets.fromLTRB(20, 0, 20, 16),
    this.scrollController,
  });

  /// The body. Wrapped in a (non-lazy) scroll view, so every section is
  /// built and `Scrollable.ensureVisible` can bring any of them into view.
  final Widget child;

  /// Sheet title, fixed under the grabber. Only the text is configurable:
  /// it's always centred, one line, in the screen-title style (Newsreader
  /// 24, semibold, espresso) — the same as the pushed screens' headers.
  final String? title;

  /// Fixed footer — buttons, fine print. Sits on the ivory bar with the
  /// home-indicator inset added below it.
  final Widget? actions;

  /// A hairline above [actions], separating the footer from the body.
  final bool actionsBorder;

  /// The most of the screen height the sheet may take (0–1). A shorter
  /// body shrinks the sheet to fit; a longer one scrolls.
  final double heightFactor;

  /// Padding around [child] inside the scroll view.
  final EdgeInsetsGeometry contentPadding;

  /// Optional controller for the body's scroll view.
  final ScrollController? scrollController;

  /// Shows [builder]'s sheet (normally an [AppBottomSheet]) as a modal with
  /// the app's scrim. Resolves to what the sheet pops with, or null when
  /// dismissed.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isDismissible = true,
    bool enableDrag = true,
    // Over the whole screen, tab bar included — a tab's own navigator ends
    // above the bar, so a sheet opened there rises from the bar. Pass false
    // to keep the sheet inside the current tab.
    bool useRootNavigator = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: useRootNavigator,
      isScrollControlled: true,
      useSafeArea: true,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      barrierColor: AppColors.espressoDeep.withValues(alpha: 0.55),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: media.size.height * heightFactor,
        ),
        clipBehavior: Clip.antiAlias,
        decoration: const BoxDecoration(
          color: AppColors.ivory,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            if (title != null) _Title(title!),
            // Loose: the body takes only what it needs, up to the cap.
            Flexible(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: contentPadding,
                  child: child,
                ),
              ),
            ),
            if (actions != null)
              Container(
                decoration: BoxDecoration(
                  color: AppColors.ivory.withValues(alpha: 0.95),
                  border: actionsBorder
                      ? const Border(top: BorderSide(color: AppColors.sand))
                      : null,
                ),
                padding: EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  12 + media.padding.bottom,
                ),
                child: actions,
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  final String text;
  const _Title(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTypography.screenTitle,
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 20),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.taupeSoft.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}
