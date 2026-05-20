import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../debug/theme_gallery_screen.dart';
import '../../modules/auth/screens/forgot_password_screen.dart';
import '../../modules/auth/screens/login_screen.dart';
import '../../modules/auth/screens/sign_up_screen.dart';
import '../../modules/auth/screens/welcome_screen.dart';
import '../../modules/onboarding/screens/age_range_screen.dart';
import '../../modules/onboarding/screens/avatar_reveal_screen.dart';
import '../../modules/onboarding/screens/chest_measurement_screen.dart';
import '../../modules/onboarding/screens/height_input_screen.dart';
import '../../modules/onboarding/screens/hips_measurement_screen.dart';
import '../../modules/onboarding/screens/inseam_measurement_screen.dart';
import '../../modules/onboarding/screens/lifestyle_occasions_screen.dart';
import '../../modules/onboarding/screens/manual_entry_screen.dart';
import '../../modules/onboarding/screens/pre_measurement_screen.dart';
import '../../modules/onboarding/screens/profile_complete_screen.dart';
import '../../modules/onboarding/screens/shopping_style_screen.dart';
import '../../modules/onboarding/screens/shoulders_screen.dart';
import '../../modules/onboarding/screens/splash_screen.dart';
import '../../modules/onboarding/screens/style_goals_screen.dart';
import '../../modules/onboarding/screens/waist_measurement_screen.dart';
import '../../modules/onboarding/screens/wardrobe_setup_screen.dart';
import '../../modules/onboarding/screens/weight_input_screen.dart';
import '../../modules/today/screens/ai_reasoning_detail_screen.dart';
import '../../modules/today/screens/outfit_history_screen.dart';
import '../../modules/today/screens/today_dashboard_screen.dart';
import '../../modules/wardrobe/screens/batch_upload_screen.dart';
import '../../modules/wardrobe/screens/intelligence_report_screen.dart';
import '../../modules/wardrobe/screens/item_detail_screen.dart';
import '../../modules/wardrobe/screens/manual_entry_screen.dart' as wardrobe_manual;
import '../../modules/wardrobe/screens/scanner_screen.dart';
import '../../modules/wardrobe/screens/wardrobe_screen.dart';
import '../../modules/wardrobe/screens/weekly_recap_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: SplashScreen.path,
    routes: [
      // ─── Boot ─────────────────────────────────────────────────
      GoRoute(
        path: SplashScreen.path,
        name: SplashScreen.name,
        builder: (_, __) => const SplashScreen(),
      ),

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

      // ─── Onboarding: style profile ────────────────────────────
      GoRoute(
        path: ShoppingStyleScreen.path,
        name: ShoppingStyleScreen.name,
        builder: (_, __) => const ShoppingStyleScreen(),
      ),
      GoRoute(
        path: AgeRangeScreen.path,
        name: AgeRangeScreen.name,
        builder: (_, __) => const AgeRangeScreen(),
      ),
      GoRoute(
        path: StyleGoalsScreen.path,
        name: StyleGoalsScreen.name,
        builder: (_, __) => const StyleGoalsScreen(),
      ),
      GoRoute(
        path: LifestyleOccasionsScreen.path,
        name: LifestyleOccasionsScreen.name,
        builder: (_, __) => const LifestyleOccasionsScreen(),
      ),

      // ─── Onboarding: measurements ─────────────────────────────
      GoRoute(
        path: PreMeasurementScreen.path,
        name: PreMeasurementScreen.name,
        builder: (_, __) => const PreMeasurementScreen(),
      ),
      GoRoute(
        path: HeightInputScreen.path,
        name: HeightInputScreen.name,
        builder: (_, __) => const HeightInputScreen(),
      ),
      GoRoute(
        path: WeightInputScreen.path,
        name: WeightInputScreen.name,
        builder: (_, __) => const WeightInputScreen(),
      ),
      GoRoute(
        path: ChestMeasurementScreen.path,
        name: ChestMeasurementScreen.name,
        builder: (_, __) => const ChestMeasurementScreen(),
      ),
      GoRoute(
        path: WaistMeasurementScreen.path,
        name: WaistMeasurementScreen.name,
        builder: (_, __) => const WaistMeasurementScreen(),
      ),
      GoRoute(
        path: HipsMeasurementScreen.path,
        name: HipsMeasurementScreen.name,
        builder: (_, __) => const HipsMeasurementScreen(),
      ),
      GoRoute(
        path: InseamMeasurementScreen.path,
        name: InseamMeasurementScreen.name,
        builder: (_, __) => const InseamMeasurementScreen(),
      ),
      GoRoute(
        path: ShouldersScreen.path,
        name: ShouldersScreen.name,
        builder: (_, __) => const ShouldersScreen(),
      ),
      GoRoute(
        path: ManualEntryScreen.path,
        name: ManualEntryScreen.name,
        builder: (_, __) => const ManualEntryScreen(),
      ),

      // ─── Onboarding: wardrobe + avatar ────────────────────────
      GoRoute(
        path: WardrobeSetupScreen.path,
        name: WardrobeSetupScreen.name,
        builder: (_, __) => const WardrobeSetupScreen(),
      ),
      GoRoute(
        path: AvatarRevealScreen.path,
        name: AvatarRevealScreen.name,
        builder: (_, __) => const AvatarRevealScreen(),
      ),
      GoRoute(
        path: ProfileCompleteScreen.path,
        name: ProfileCompleteScreen.name,
        builder: (_, __) => const ProfileCompleteScreen(),
      ),

      // ─── Today ────────────────────────────────────────────────
      GoRoute(
        path: TodayDashboardScreen.path,
        name: TodayDashboardScreen.name,
        builder: (_, __) => const TodayDashboardScreen(),
        routes: [
          GoRoute(
            path: 'history',
            name: OutfitHistoryScreen.name,
            builder: (_, __) => const OutfitHistoryScreen(),
          ),
          GoRoute(
            path: 'outfit/:id/reasoning',
            name: AiReasoningDetailScreen.name,
            pageBuilder: (_, state) => CustomTransitionPage(
              opaque: false,
              barrierDismissible: true,
              fullscreenDialog: true,
              transitionsBuilder: (_, animation, __, child) {
                return SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  )),
                  child: child,
                );
              },
              child: AiReasoningDetailScreen(
                outfitId: state.pathParameters['id']!,
              ),
            ),
          ),
        ],
      ),

      // ─── Wardrobe ─────────────────────────────────────────────
      GoRoute(
        path: WardrobeScreen.path,
        name: WardrobeScreen.name,
        builder: (_, __) => const WardrobeScreen(),
        routes: [
          GoRoute(
            path: ScannerScreen.path,
            name: ScannerScreen.name,
            builder: (_, __) => const ScannerScreen(),
          ),
          GoRoute(
            path: BatchUploadScreen.path,
            name: BatchUploadScreen.name,
            builder: (_, __) => const BatchUploadScreen(),
          ),
          GoRoute(
            path: wardrobe_manual.ManualEntryScreen.path,
            name: wardrobe_manual.ManualEntryScreen.name,
            builder: (_, __) => const wardrobe_manual.ManualEntryScreen(),
          ),
          GoRoute(
            path: IntelligenceReportScreen.path,
            name: IntelligenceReportScreen.name,
            builder: (_, __) => const IntelligenceReportScreen(),
          ),
          GoRoute(
            path: WeeklyRecapScreen.path,
            name: WeeklyRecapScreen.name,
            builder: (_, __) => const WeeklyRecapScreen(),
          ),
          GoRoute(
            path: ItemDetailScreen.path,
            name: ItemDetailScreen.name,
            builder: (_, state) => ItemDetailScreen(
              itemId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),

      // ─── Debug ────────────────────────────────────────────────
      GoRoute(
        path: ThemeGalleryScreen.path,
        name: ThemeGalleryScreen.name,
        builder: (_, __) => const ThemeGalleryScreen(),
      ),
    ],
  );
});
