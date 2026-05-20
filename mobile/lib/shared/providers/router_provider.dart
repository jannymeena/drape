import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/sign_up_screen.dart';
import '../../modules/auth/screens/welcome_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: WelcomeScreen.path,
    routes: [
      // ─── Auth ─────────────────────────────────────────────────
      GoRoute(
        path: WelcomeScreen.path,
        name: WelcomeScreen.name,
        builder: (_, __) => const WelcomeScreen(),
      ),
      GoRoute(
        path: SignUpScreen.path,
        name: SignUpScreen.name,
        builder: (_, __) => const SignUpScreen(),
      ),
      GoRoute(
        path: LoginScreen.path,
        name: LoginScreen.name,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: ForgotPasswordScreen.path,
        name: ForgotPasswordScreen.name,
        builder: (_, __) => const ForgotPasswordScreen(),
      ),

      // ─── Debug ────────────────────────────────────────────────
      GoRoute(
        path: ThemeGalleryScreen.path,
        name: ThemeGalleryScreen.name,
        builder: (_, __) => const ThemeGalleryScreen(),
      ),

      // Phase C2 adds splash + onboarding routes here.
    ],
  );
});
