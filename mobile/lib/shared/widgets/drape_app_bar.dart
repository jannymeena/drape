import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class DrapeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool showBack;

  const DrapeAppBar({
    super.key,
    this.title,
    this.onBack,
    this.actions = const [],
    this.showBack = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    // Only render the default back arrow when there's actually something to pop;
    // otherwise it's a dead control (e.g. the first onboarding step, or a step
    // resumed directly via `go`). A custom [onBack] always shows.
    final canGoBack = onBack != null || Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: AppColors.ivory,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      automaticallyImplyLeading: false,
      leading: showBack && canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              onPressed: onBack ?? () => Navigator.maybePop(context),
            )
          : null,
      title: title == null
          ? null
          : Text(
              title!,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink,
                  ),
            ),
      actions: actions,
    );
  }
}
