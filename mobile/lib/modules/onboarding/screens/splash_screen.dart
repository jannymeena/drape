import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/services/session_store.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../today/screens/today_dashboard_screen.dart';

class SplashScreen extends StatefulWidget {
  static const path = '/splash';
  static const name = 'splash';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Phase E: replace with /profile/onboarding-status check → resume route.
    final loggedIn = await SessionStore.isLoggedIn();
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    context.goNamed(
      loggedIn ? TodayDashboardScreen.name : WelcomeScreen.name,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.espressoDeep,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('DRAPE', style: AppTypography.brandMark),
              const SizedBox(height: 12),
              Text('Your personal stylist.', style: AppTypography.tagline),
            ],
          ),
        ),
      ),
    );
  }
}
