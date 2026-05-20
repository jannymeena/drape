import 'screens/age_range_screen.dart';
import 'screens/avatar_reveal_screen.dart';
import 'screens/chest_measurement_screen.dart';
import 'screens/height_input_screen.dart';
import 'screens/hips_measurement_screen.dart';
import 'screens/inseam_measurement_screen.dart';
import 'screens/lifestyle_occasions_screen.dart';
import 'screens/profile_complete_screen.dart';
import 'screens/shopping_style_screen.dart';
import 'screens/shoulders_screen.dart';
import 'screens/style_goals_screen.dart';
import 'screens/waist_measurement_screen.dart';
import 'screens/wardrobe_setup_screen.dart';
import 'screens/weight_input_screen.dart';

/// Maps the `users.onboarding_last_step` string returned by
/// `GET /profile/onboarding-status` to the route name the user should resume
/// at on the NEXT incomplete step.
///
/// Source of truth for step ids: backend `plan.md` §Phase 5a–5d. Update both
/// when steps are renamed.
///
/// Phase E will read the backend's `next_step` field directly; this map is
/// the offline fallback when only `last_step` is available, and the lookup
/// table used by the resume button's local logic.
const Map<String, String> onboardingResumeRoutes = {
  // No progress yet → start of style profile.
  '': ShoppingStyleScreen.name,
  'shopping_style': AgeRangeScreen.name,
  'age_range': StyleGoalsScreen.name,
  'style_goals': LifestyleOccasionsScreen.name,
  'lifestyle_occasions': HeightInputScreen.name,

  // Measurement substeps (chest/waist/hips/inseam/shoulders = 8-step indicator).
  'measurements_step_1': WeightInputScreen.name, // height done
  'measurements_step_2': ChestMeasurementScreen.name, // weight done
  'measurements_step_3': WaistMeasurementScreen.name,
  'measurements_step_4': HipsMeasurementScreen.name,
  'measurements_step_5': InseamMeasurementScreen.name,
  'measurements_step_6': ShouldersScreen.name,
  'measurements_step_7': WardrobeSetupScreen.name,
  'measurements_step_8': WardrobeSetupScreen.name,

  // Wardrobe + avatar.
  'wardrobe_assigned': AvatarRevealScreen.name,
  'avatar_generated': ProfileCompleteScreen.name,
};

/// Returns the route name to resume onboarding from, given the last completed
/// step id. Unknown ids fall back to the first onboarding screen.
String resumeRouteFor(String? lastStep) {
  if (lastStep == null) return ShoppingStyleScreen.name;
  return onboardingResumeRoutes[lastStep] ?? ShoppingStyleScreen.name;
}
