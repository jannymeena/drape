import 'screens/age_range_screen.dart';
import 'screens/avatar_reveal_screen.dart';
import 'screens/chest_measurement_screen.dart';
import 'screens/height_input_screen.dart';
import 'screens/hips_measurement_screen.dart';
import 'screens/inseam_measurement_screen.dart';
import 'screens/pre_measurement_screen.dart';
import 'screens/shopping_style_screen.dart';
import 'screens/shoulders_screen.dart';
import 'screens/style_goals_screen.dart';
import 'screens/thigh_measurement_screen.dart';
import 'screens/waist_measurement_screen.dart';
import 'screens/weight_input_screen.dart';

/// Maps the backend's `next_step` (`OnboardingStep`, returned by
/// `GET /profile/onboarding-status`) to the route to resume at on launch.
///
/// Source of truth for the step ids: backend `app/services/profile_service.py`
/// `_NEXT`. Update both when steps are renamed. Note these are *forward* step
/// ids (the next step to do) — distinct from the `last_completed_step` written
/// by save-progress.
///
/// `today_dashboard` is intentionally absent: it means "onboarding is finished",
/// which the splash handles by routing to the Today tab (see [isOnboardingDone]).
const Map<String, String> _nextStepRoutes = {
  'shopping_style_selection': ShoppingStyleScreen.name,
  'age_range': AgeRangeScreen.name,
  'style_goals': StyleGoalsScreen.name,
  'pre_measurement_intro': PreMeasurementScreen.name,
  'measurements_step_1': HeightInputScreen.name,
  'measurements_step_2': WeightInputScreen.name,
  'measurements_step_3': ChestMeasurementScreen.name,
  'measurements_step_4': WaistMeasurementScreen.name,
  'measurements_step_5': HipsMeasurementScreen.name,
  'measurements_step_6': InseamMeasurementScreen.name,
  'measurements_step_7': ThighMeasurementScreen.name,
  'measurements_step_8': ShouldersScreen.name,
  'avatar_reveal': AvatarRevealScreen.name,
};

/// True when [nextStep] indicates onboarding is complete (→ go to Today).
bool isOnboardingDone(String nextStep) => nextStep == 'today_dashboard';

/// The onboarding route to resume from. Unknown ids fall back to the first
/// screen rather than stranding the user.
String routeForNextStep(String? nextStep) =>
    _nextStepRoutes[nextStep] ?? ShoppingStyleScreen.name;
