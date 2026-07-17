/// Every analytics event name, in one place (MOBILE_CHANGES P1).
///
/// Names come from the `analytics.track(...)` specs in the handoff docs;
/// deviations are commented where they occur. Server-side events
/// (`push_notification_sent`, `starter_wardrobe_assigned/deactivated`) and the
/// obsolete `avatar_*` events are deliberately absent.
abstract final class AnalyticsEvents {
  // --- Launch / auth funnel ---
  static const appLaunched = 'app_launched';
  static const welcomeSlideViewed = 'welcome_slide_viewed';
  static const welcomeSkipped = 'welcome_skipped';
  static const signupStarted = 'signup_started';
  static const signupCompleted = 'signup_completed';
  static const signupFailed = 'signup_failed';
  static const loginCompleted = 'login_completed';

  // --- Onboarding funnel ---
  static const shoppingStyleSelected = 'shopping_style_selected';
  static const ageRangeSelected = 'age_range_selected';
  static const styleGoalsSelected = 'style_goals_selected';
  static const preMeasurementViewed = 'pre_measurement_viewed';
  static const measurementsStarted = 'measurements_started';
  static const measurementStepCompleted = 'measurement_step_completed';
  static const allMeasurementsCompleted = 'all_measurements_completed';
  static const measurementsSkipped = 'measurements_skipped';
  static const skipConfirmationShown = 'skip_confirmation_shown';
  static const skipConfirmationAction = 'skip_confirmation_action';
  static const onboardingCompleted = 'onboarding_completed';

  // --- Today engagement ---
  static const todayDashboardViewed = 'today_dashboard_viewed';
  static const outfitCardViewed = 'outfit_card_viewed';
  // The docs never named the regenerate event (MOBILE_CHANGES P1 note).
  static const outfitRegenerated = 'outfit_regenerated';
  static const outfitLogged = 'outfit_logged';
  static const itemLoggedAsWorn = 'item_logged_as_worn';
  static const mixAndMatchOpened = 'mix_and_match_opened';
  static const mixAndMatchSaved = 'mix_and_match_saved';
  static const outfitItemSwapped = 'outfit_item_swapped';
  static const aiReasoningViewed = 'ai_reasoning_viewed';
  static const outfitHistoryViewed = 'outfit_history_viewed';
  static const outfitHistoryRowTapped = 'outfit_history_row_tapped';
  static const starterWardrobeBannerShown = 'starter_wardrobe_banner_shown';
  static const starterWardrobeBannerDismissed =
      'starter_wardrobe_banner_dismissed';
  static const starterWardrobeAddItemsTapped =
      'starter_wardrobe_add_items_tapped';
  static const resumeBannerShown = 'resume_banner_shown';
  static const resumeBannerTapped = 'resume_banner_tapped';

  // --- Limits / conversion ---
  static const usageLimitWarningShown = 'usage_limit_warning_shown';
  static const usageLimitReached = 'usage_limit_reached';
  static const proTeaseShown = 'pro_tease_shown';
  static const proUpgradeTappedFromLimit = 'pro_upgrade_tapped_from_limit';
  static const upgradeTapped = 'upgrade_tapped';
  static const paywallViewed = 'paywall_viewed';
  static const subscriptionStarted = 'subscription_started';
  static const subscriptionCanceled = 'subscription_canceled';
  static const subscriptionReactivated = 'subscription_reactivated';

  // --- Wardrobe ---
  static const wardrobeTabViewed = 'wardrobe_tab_viewed';
  static const wardrobeEmptyStateViewed = 'wardrobe_empty_state_viewed';
  static const wardrobeFabTapped = 'wardrobe_fab_tapped';
  static const addWardrobeChooserOpened = 'add_wardrobe_chooser_opened';
  static const addMethodSelected = 'add_method_selected';
  static const scannerOpened = 'scanner_opened';
  static const scannerDetectionSuccess = 'scanner_detection_success';
  static const scannerDetectionFailed = 'scanner_detection_failed';
  static const scannerItemAdded = 'scanner_item_added';
  // Shared by the onboarding and wardrobe manual-entry screens — the `source`
  // property distinguishes them.
  static const manualEntryOpened = 'manual_entry_opened';
  static const manualEntrySubmitted = 'manual_entry_submitted';
  static const itemDetailViewed = 'item_detail_viewed';
  static const itemEditTapped = 'item_edit_tapped';
  static const itemRemoved = 'item_removed';
  static const removeItemConfirmationShown = 'remove_item_confirmation_shown';
  static const wardrobeLimitModalShown = 'wardrobe_limit_modal_shown';
  static const wardrobeLimitModalAction = 'wardrobe_limit_modal_action';

  // --- Shop ---
  static const aiStyleAdvisorOpened = 'ai_style_advisor_opened';
  static const aiStyleAdvisorQuestionAsked = 'ai_style_advisor_question_asked';
  static const aiAdvisorLimitReached = 'ai_advisor_limit_reached';
  static const buyDontBuyWarningShown = 'buy_dont_buy_warning_shown';
  static const buyDontBuyLimitReached = 'buy_dont_buy_limit_reached';
  static const measurementModalShown = 'measurement_modal_shown';

  // --- Push (P3) ---
  static const pushPermissionResult = 'push_permission_result';
  static const pushNotificationTapped = 'push_notification_tapped';
  static const pushForegroundReceived = 'push_foreground_received';
}
