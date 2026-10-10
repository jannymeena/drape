import 'package:flutter/material.dart';

/// Closes the keyboard when the user taps outside the focused text field,
/// for every text field below it.
///
/// Flutter's default drops focus on a touch only on desktop/web, which left
/// the keyboard stuck on phones — the iOS number pad has no Done key at all.
/// Taps on another text field don't count as outside (text fields share one
/// tap region), so moving between fields keeps the keyboard up.
class KeyboardDismissOnTapOutside extends StatelessWidget {
  final Widget child;

  const KeyboardDismissOnTapOutside({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Actions(
      actions: {
        EditableTextTapOutsideIntent:
            CallbackAction<EditableTextTapOutsideIntent>(
          onInvoke: (intent) => intent.focusNode.unfocus(),
        ),
      },
      child: child,
    );
  }
}
