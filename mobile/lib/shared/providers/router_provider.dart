import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: ThemeGalleryScreen.path,
    routes: [
      // ─── Debug ────────────────────────────────────────────────
      GoRoute(
        path: ThemeGalleryScreen.path,
        name: ThemeGalleryScreen.name,
        builder: (_, __) => const ThemeGalleryScreen(),
      ),

      // Phase C will add splash, welcome, auth, onboarding, today, wardrobe, profile, billing.
    ],
  );
});
