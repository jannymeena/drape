import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The ZOURA wordmark line. Tabs pass their [actions]; nested screens use it
/// bare via [NestedHeader]. Fixed height so the wordmark sits in exactly the
/// same spot with or without icons — it must not jump between screens.
class ZouraTopBar extends StatelessWidget {
  final List<Widget> actions;
  const ZouraTopBar({super.key, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            Text(
              'ZOURA',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.espresso,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const Spacer(),
            ...actions,
          ],
        ),
      ),
    );
  }
}

/// Header for every screen pushed from a tab: the ZOURA line, then a row with
/// the back (or close) button, the title left-aligned right next to it, and an
/// optional [action] on the right.
class NestedHeader extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  final Widget? action;
  final IconData backIcon;

  const NestedHeader({
    super.key,
    required this.title,
    required this.onBack,
    this.action,
    this.backIcon = Icons.arrow_back,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ZouraTopBar(),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
          child: Row(
            children: [
              IconButton(
                icon: Icon(backIcon, color: AppColors.espresso),
                onPressed: onBack,
              ),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ],
    );
  }
}
