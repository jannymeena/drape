import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/models/api_error.dart';
import '../../../shared/providers/analytics_provider.dart';
import '../../../shared/services/analytics/analytics_events.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../auth/auth_controller.dart';
import '../../auth/screens/welcome_screen.dart';
import '../../today/screens/today_dashboard_screen.dart';
import '../onboarding_controller.dart';
import '../resume_route_map.dart';

class SplashScreen extends ConsumerStatefulWidget {
  static const path = '/splash';
  static const name = 'splash';

  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Restore + validate any stored session against `/users/me`, while the
    // splash mark holds for its minimum dwell. A stale token clears itself
    // inside bootstrap() and we fall through to Welcome.
    final results = await Future.wait([
      ref.read(authControllerProvider.notifier).bootstrap(),
      Future<void>.delayed(const Duration(seconds: 2)),
    ]);
    final restored = results.first as bool;
    if (!mounted) return;
    ref
        .read(analyticsProvider)
        .capture(AnalyticsEvents.appLaunched, {'has_valid_token': restored});
    if (!restored) {
      context.goNamed(WelcomeScreen.name);
      return;
    }

    // Signed in: resume where onboarding left off (or Today if it's done).
    // A status fetch that fails shouldn't strand the user — they have a valid
    // session, so default to Today.
    try {
      final status = await ref
          .read(onboardingControllerProvider.notifier)
          .loadAndHydrate();
      if (!mounted) return;
      if (status.onboardingCompleted || isOnboardingDone(status.nextStep)) {
        context.goNamed(TodayDashboardScreen.name);
      } else {
        context.goNamed(routeForNextStep(status.nextStep));
      }
    } on ApiException {
      if (mounted) context.goNamed(TodayDashboardScreen.name);
    }
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
