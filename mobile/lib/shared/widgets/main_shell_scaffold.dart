import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import 'drape_bottom_nav.dart';

/// Hosts the four tab branches of the main app shell so each tab keeps its
/// own back stack and switching tabs doesn't reset scroll position.
///
/// `navigationShell` is supplied by `StatefulShellRoute.indexedStack`.
class MainShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainShellScaffold({super.key, required this.navigationShell});

  static const _destinations = DrapeNavDestination.values;

  @override
  Widget build(BuildContext context) {
    final current = _destinations[navigationShell.currentIndex];
    return Scaffold(
      backgroundColor: AppColors.ivory,
      body: navigationShell,
      bottomNavigationBar: DrapeBottomNav(
        current: current,
        onSelected: (dest) => _goBranch(_destinations.indexOf(dest)),
      ),
    );
  }

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
