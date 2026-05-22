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
import '../../modules/profile/screens/account_settings_screen.dart';
import '../../modules/profile/screens/appearance_settings_screen.dart';
import '../../modules/profile/screens/billing_history_screen.dart';
import '../../modules/profile/screens/bug_report_success_screen.dart';
import '../../modules/profile/screens/compare_plans_screen.dart';
import '../../modules/profile/screens/contact_us_screen.dart';
import '../../modules/profile/screens/delete_account_screen.dart';
import '../../modules/profile/screens/edit_profile_screen.dart';
import '../../modules/profile/screens/email_password_settings_screen.dart';
import '../../modules/profile/screens/export_my_data_screen.dart';
import '../../modules/profile/screens/faqs_screen.dart';
import '../../modules/profile/screens/feature_request_screen.dart';
import '../../modules/profile/screens/feature_request_success_screen.dart';
import '../../modules/profile/screens/final_cancellation_confirmation_screen.dart';
import '../../modules/profile/screens/help_center_hub_screen.dart';
import '../../modules/profile/screens/how_drape_uses_data_screen.dart';
import '../../modules/profile/screens/notifications_preferences_screen.dart';
import '../../modules/profile/screens/payment_methods_screen.dart';
import '../../modules/profile/screens/privacy_data_screen.dart';
import '../../modules/profile/screens/profile_intelligence_screen.dart';
import '../../modules/profile/screens/report_bug_screen.dart';
import '../../modules/profile/screens/retention_offer_screen.dart';
import '../../modules/profile/screens/settings_screen.dart';
import '../../modules/profile/screens/style_preferences_screen.dart';
import '../../modules/profile/screens/subscription_management_screen.dart';
import '../../modules/shop/screens/ai_advisor_conversation_screen.dart';
import '../../modules/shop/screens/ai_advisor_history_screen.dart';
import '../../modules/shop/screens/ai_advisor_initial_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_choose_image_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_confirm_product_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_limit_reached_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_scan_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_scanning_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_verdict_buy_screen.dart';
import '../../modules/shop/screens/buy_dont_buy_verdict_dont_buy_screen.dart';
import '../../modules/shop/screens/gap_analysis_screen.dart';
import '../../modules/shop/screens/in_app_browser_screen.dart';
import '../../modules/shop/screens/shop_feed_empty_screen.dart';
import '../../modules/shop/screens/shop_feed_loading_screen.dart';
import '../../modules/shop/screens/shop_feed_screen.dart';
import '../../modules/shop/screens/wishlist_screen.dart';
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
import '../services/session_store.dart';
import '../widgets/main_shell_scaffold.dart';

final _rootNavKey = GlobalKey<NavigatorState>();
final _todayNavKey = GlobalKey<NavigatorState>();
final _wardrobeNavKey = GlobalKey<NavigatorState>();
final _shopNavKey = GlobalKey<NavigatorState>();
final _profileNavKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavKey,
    initialLocation: SplashScreen.path,
    // Re-run `redirect` whenever the session flag flips (login / logout).
    refreshListenable: SessionStore.state,
    // Auth gate: the four main-shell tabs require a session. Auth, onboarding,
    // splash, and debug routes stay open. Logged-out access to a protected
    // route bounces to Welcome.
    redirect: (context, state) {
      const protectedPrefixes = [
        TodayDashboardScreen.path,
        WardrobeScreen.path,
        ShopFeedScreen.path,
        ProfileIntelligenceScreen.path,
      ];
      final loc = state.matchedLocation;
      final isProtected = protectedPrefixes.any((p) => loc.startsWith(p));
      if (isProtected && !SessionStore.state.value) {
        return WelcomeScreen.path;
      }
      return null;
    },
    routes: [
      // ─── Boot ─────────────────────────────────────────────────
      GoRoute(
        path: SplashScreen.path,
        name: SplashScreen.name,
        builder: (_, _) => const SplashScreen(),
      ),

      // ─── Auth ─────────────────────────────────────────────────
      GoRoute(
        path: WelcomeScreen.path,
        name: WelcomeScreen.name,
        builder: (_, _) => const WelcomeScreen(),
      ),
      GoRoute(
        path: SignUpScreen.path,
        name: SignUpScreen.name,
        builder: (_, _) => const SignUpScreen(),
      ),
      GoRoute(
        path: LoginScreen.path,
        name: LoginScreen.name,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: ForgotPasswordScreen.path,
        name: ForgotPasswordScreen.name,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),

      // ─── Onboarding: style profile ────────────────────────────
      GoRoute(
        path: ShoppingStyleScreen.path,
        name: ShoppingStyleScreen.name,
        builder: (_, _) => const ShoppingStyleScreen(),
      ),
      GoRoute(
        path: AgeRangeScreen.path,
        name: AgeRangeScreen.name,
        builder: (_, _) => const AgeRangeScreen(),
      ),
      GoRoute(
        path: StyleGoalsScreen.path,
        name: StyleGoalsScreen.name,
        builder: (_, _) => const StyleGoalsScreen(),
      ),
      GoRoute(
        path: LifestyleOccasionsScreen.path,
        name: LifestyleOccasionsScreen.name,
        builder: (_, _) => const LifestyleOccasionsScreen(),
      ),

      // ─── Onboarding: measurements ─────────────────────────────
      GoRoute(
        path: PreMeasurementScreen.path,
        name: PreMeasurementScreen.name,
        builder: (_, _) => const PreMeasurementScreen(),
      ),
      GoRoute(
        path: HeightInputScreen.path,
        name: HeightInputScreen.name,
        builder: (_, _) => const HeightInputScreen(),
      ),
      GoRoute(
        path: WeightInputScreen.path,
        name: WeightInputScreen.name,
        builder: (_, _) => const WeightInputScreen(),
      ),
      GoRoute(
        path: ChestMeasurementScreen.path,
        name: ChestMeasurementScreen.name,
        builder: (_, _) => const ChestMeasurementScreen(),
      ),
      GoRoute(
        path: WaistMeasurementScreen.path,
        name: WaistMeasurementScreen.name,
        builder: (_, _) => const WaistMeasurementScreen(),
      ),
      GoRoute(
        path: HipsMeasurementScreen.path,
        name: HipsMeasurementScreen.name,
        builder: (_, _) => const HipsMeasurementScreen(),
      ),
      GoRoute(
        path: InseamMeasurementScreen.path,
        name: InseamMeasurementScreen.name,
        builder: (_, _) => const InseamMeasurementScreen(),
      ),
      GoRoute(
        path: ShouldersScreen.path,
        name: ShouldersScreen.name,
        builder: (_, _) => const ShouldersScreen(),
      ),
      GoRoute(
        path: ManualEntryScreen.path,
        name: ManualEntryScreen.name,
        builder: (_, _) => const ManualEntryScreen(),
      ),

      // ─── Onboarding: wardrobe + avatar ────────────────────────
      GoRoute(
        path: WardrobeSetupScreen.path,
        name: WardrobeSetupScreen.name,
        builder: (_, _) => const WardrobeSetupScreen(),
      ),
      GoRoute(
        path: AvatarRevealScreen.path,
        name: AvatarRevealScreen.name,
        builder: (_, _) => const AvatarRevealScreen(),
      ),
      GoRoute(
        path: ProfileCompleteScreen.path,
        name: ProfileCompleteScreen.name,
        builder: (_, _) => const ProfileCompleteScreen(),
      ),

      // ─── Main app shell (Today / Wardrobe / Shop / Profile) ──
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainShellScaffold(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _todayNavKey,
            routes: [
              GoRoute(
                path: TodayDashboardScreen.path,
                name: TodayDashboardScreen.name,
                builder: (_, _) => const TodayDashboardScreen(),
                routes: [
                  GoRoute(
                    path: 'history',
                    name: OutfitHistoryScreen.name,
                    builder: (_, _) => const OutfitHistoryScreen(),
                  ),
                  GoRoute(
                    path: 'outfit/:id/reasoning',
                    name: AiReasoningDetailScreen.name,
                    parentNavigatorKey: _rootNavKey,
                    pageBuilder: (_, state) => CustomTransitionPage(
                      opaque: false,
                      barrierDismissible: true,
                      fullscreenDialog: true,
                      transitionsBuilder: (_, animation, _, child) {
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
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _wardrobeNavKey,
            routes: [
              GoRoute(
                path: WardrobeScreen.path,
                name: WardrobeScreen.name,
                builder: (_, _) => const WardrobeScreen(),
                routes: [
                  GoRoute(
                    path: ScannerScreen.path,
                    name: ScannerScreen.name,
                    parentNavigatorKey: _rootNavKey,
                    builder: (_, _) => const ScannerScreen(),
                  ),
                  GoRoute(
                    path: BatchUploadScreen.path,
                    name: BatchUploadScreen.name,
                    builder: (_, _) => const BatchUploadScreen(),
                  ),
                  GoRoute(
                    path: wardrobe_manual.ManualEntryScreen.path,
                    name: wardrobe_manual.ManualEntryScreen.name,
                    builder: (_, _) => const wardrobe_manual.ManualEntryScreen(),
                  ),
                  GoRoute(
                    path: IntelligenceReportScreen.path,
                    name: IntelligenceReportScreen.name,
                    builder: (_, _) => const IntelligenceReportScreen(),
                  ),
                  GoRoute(
                    path: WeeklyRecapScreen.path,
                    name: WeeklyRecapScreen.name,
                    builder: (_, _) => const WeeklyRecapScreen(),
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
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shopNavKey,
            routes: [
              GoRoute(
                path: ShopFeedScreen.path,
                name: ShopFeedScreen.name,
                builder: (_, _) => const ShopFeedScreen(),
                routes: [
                  GoRoute(
                    path: ShopFeedEmptyScreen.path,
                    name: ShopFeedEmptyScreen.name,
                    builder: (_, _) => const ShopFeedEmptyScreen(),
                  ),
                  GoRoute(
                    path: ShopFeedLoadingScreen.path,
                    name: ShopFeedLoadingScreen.name,
                    builder: (_, _) => const ShopFeedLoadingScreen(),
                  ),
                  GoRoute(
                    path: AiAdvisorInitialScreen.path,
                    name: AiAdvisorInitialScreen.name,
                    builder: (_, _) => const AiAdvisorInitialScreen(),
                  ),
                  GoRoute(
                    path: AiAdvisorConversationScreen.path,
                    name: AiAdvisorConversationScreen.name,
                    builder: (_, _) => const AiAdvisorConversationScreen(),
                  ),
                  GoRoute(
                    path: AiAdvisorHistoryScreen.path,
                    name: AiAdvisorHistoryScreen.name,
                    builder: (_, _) => const AiAdvisorHistoryScreen(),
                  ),
                  GoRoute(
                    path: GapAnalysisScreen.path,
                    name: GapAnalysisScreen.name,
                    builder: (_, _) => const GapAnalysisScreen(),
                  ),
                  GoRoute(
                    path: BuyDontBuyScanScreen.path,
                    name: BuyDontBuyScanScreen.name,
                    builder: (_, _) => const BuyDontBuyScanScreen(),
                  ),
                  GoRoute(
                    path: BuyDontBuyScanningScreen.path,
                    name: BuyDontBuyScanningScreen.name,
                    builder: (_, _) => const BuyDontBuyScanningScreen(),
                  ),
                  GoRoute(
                    path: ConfirmProductScreen.path,
                    name: ConfirmProductScreen.name,
                    builder: (_, _) => const ConfirmProductScreen(),
                  ),
                  GoRoute(
                    path: ChooseProductImageScreen.path,
                    name: ChooseProductImageScreen.name,
                    builder: (_, _) => const ChooseProductImageScreen(),
                  ),
                  GoRoute(
                    path: BuyDontBuyVerdictBuyScreen.path,
                    name: BuyDontBuyVerdictBuyScreen.name,
                    builder: (_, _) => const BuyDontBuyVerdictBuyScreen(),
                  ),
                  GoRoute(
                    path: BuyDontBuyVerdictDontBuyScreen.path,
                    name: BuyDontBuyVerdictDontBuyScreen.name,
                    builder: (_, _) => const BuyDontBuyVerdictDontBuyScreen(),
                  ),
                  GoRoute(
                    path: BuyDontBuyLimitReachedScreen.path,
                    name: BuyDontBuyLimitReachedScreen.name,
                    builder: (_, _) => const BuyDontBuyLimitReachedScreen(),
                  ),
                  GoRoute(
                    path: InAppBrowserScreen.path,
                    name: InAppBrowserScreen.name,
                    builder: (_, _) => const InAppBrowserScreen(),
                  ),
                  GoRoute(
                    path: WishlistScreen.path,
                    name: WishlistScreen.name,
                    builder: (_, _) => const WishlistScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _profileNavKey,
            routes: [
              GoRoute(
                path: ProfileIntelligenceScreen.path,
                name: ProfileIntelligenceScreen.name,
                builder: (_, _) => const ProfileIntelligenceScreen(),
                routes: [
                  GoRoute(
                    path: SettingsScreen.path,
                    name: SettingsScreen.name,
                    builder: (_, _) => const SettingsScreen(),
                  ),
                  GoRoute(
                    path: AccountSettingsScreen.path,
                    name: AccountSettingsScreen.name,
                    builder: (_, _) => const AccountSettingsScreen(),
                  ),
                  GoRoute(
                    path: EditProfileScreen.path,
                    name: EditProfileScreen.name,
                    builder: (_, _) => const EditProfileScreen(),
                  ),
                  GoRoute(
                    path: EmailPasswordSettingsScreen.path,
                    name: EmailPasswordSettingsScreen.name,
                    builder: (_, _) => const EmailPasswordSettingsScreen(),
                  ),
                  GoRoute(
                    path: PaymentMethodsScreen.path,
                    name: PaymentMethodsScreen.name,
                    builder: (_, _) => const PaymentMethodsScreen(),
                  ),
                  GoRoute(
                    path: NotificationsPreferencesScreen.path,
                    name: NotificationsPreferencesScreen.name,
                    builder: (_, _) => const NotificationsPreferencesScreen(),
                  ),
                  GoRoute(
                    path: AppearanceSettingsScreen.path,
                    name: AppearanceSettingsScreen.name,
                    builder: (_, _) => const AppearanceSettingsScreen(),
                  ),
                  GoRoute(
                    path: StylePreferencesScreen.path,
                    name: StylePreferencesScreen.name,
                    builder: (_, _) => const StylePreferencesScreen(),
                  ),
                  GoRoute(
                    path: SubscriptionManagementScreen.path,
                    name: SubscriptionManagementScreen.name,
                    builder: (_, _) => const SubscriptionManagementScreen(),
                  ),
                  GoRoute(
                    path: BillingHistoryScreen.path,
                    name: BillingHistoryScreen.name,
                    builder: (_, _) => const BillingHistoryScreen(),
                  ),
                  GoRoute(
                    path: RetentionOfferScreen.path,
                    name: RetentionOfferScreen.name,
                    builder: (_, _) => const RetentionOfferScreen(),
                  ),
                  GoRoute(
                    path: FinalCancellationConfirmationScreen.path,
                    name: FinalCancellationConfirmationScreen.name,
                    builder: (_, _) => const FinalCancellationConfirmationScreen(),
                  ),
                  GoRoute(
                    path: ComparePlansScreen.path,
                    name: ComparePlansScreen.name,
                    builder: (_, _) => const ComparePlansScreen(),
                  ),
                  GoRoute(
                    path: PrivacyDataScreen.path,
                    name: PrivacyDataScreen.name,
                    builder: (_, _) => const PrivacyDataScreen(),
                  ),
                  GoRoute(
                    path: HowDrapeUsesDataScreen.path,
                    name: HowDrapeUsesDataScreen.name,
                    builder: (_, _) => const HowDrapeUsesDataScreen(),
                  ),
                  GoRoute(
                    path: ExportMyDataScreen.path,
                    name: ExportMyDataScreen.name,
                    builder: (_, _) => const ExportMyDataScreen(),
                  ),
                  GoRoute(
                    path: DeleteAccountScreen.path,
                    name: DeleteAccountScreen.name,
                    builder: (_, _) => const DeleteAccountScreen(),
                  ),
                  GoRoute(
                    path: HelpCenterHubScreen.path,
                    name: HelpCenterHubScreen.name,
                    builder: (_, _) => const HelpCenterHubScreen(),
                  ),
                  GoRoute(
                    path: FaqsScreen.path,
                    name: FaqsScreen.name,
                    builder: (_, _) => const FaqsScreen(),
                  ),
                  GoRoute(
                    path: ContactUsScreen.path,
                    name: ContactUsScreen.name,
                    builder: (_, _) => const ContactUsScreen(),
                  ),
                  GoRoute(
                    path: ReportBugScreen.path,
                    name: ReportBugScreen.name,
                    builder: (_, _) => const ReportBugScreen(),
                  ),
                  GoRoute(
                    path: BugReportSuccessScreen.path,
                    name: BugReportSuccessScreen.name,
                    builder: (_, _) => const BugReportSuccessScreen(),
                  ),
                  GoRoute(
                    path: FeatureRequestScreen.path,
                    name: FeatureRequestScreen.name,
                    builder: (_, _) => const FeatureRequestScreen(),
                  ),
                  GoRoute(
                    path: FeatureRequestSuccessScreen.path,
                    name: FeatureRequestSuccessScreen.name,
                    builder: (_, _) => const FeatureRequestSuccessScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // ─── Debug ────────────────────────────────────────────────
      GoRoute(
        path: ThemeGalleryScreen.path,
        name: ThemeGalleryScreen.name,
        builder: (_, _) => const ThemeGalleryScreen(),
      ),
    ],
  );
});
