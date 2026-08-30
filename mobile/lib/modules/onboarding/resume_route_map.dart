import 'screens/blueprint_aesthetics_screen.dart';
import 'screens/blueprint_color_screen.dart';
import 'screens/blueprint_fit_screen.dart';
import 'screens/blueprint_goals_screen.dart';
import 'screens/blueprint_habits_screen.dart';
import 'screens/blueprint_identity_screen.dart';
import 'screens/blueprint_lifestyle_screen.dart';
import 'screens/blueprint_reveal_screen.dart';

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
  'style_blueprint_1': BlueprintIdentityScreen.name,
  'style_blueprint_2': BlueprintFitScreen.name,
  'style_blueprint_3': BlueprintAestheticsScreen.name,
  'style_blueprint_4': BlueprintColorScreen.name,
  'style_blueprint_5': BlueprintLifestyleScreen.name,
  'style_blueprint_6': BlueprintHabitsScreen.name,
  'style_blueprint_7': BlueprintGoalsScreen.name,
  'style_blueprint_reveal': BlueprintRevealScreen.name,
};

/// True when [nextStep] indicates onboarding is complete (→ go to Today).
bool isOnboardingDone(String nextStep) => nextStep == 'today_dashboard';

/// The onboarding route to resume from. Unknown ids — including the
/// pre-redesign step names, which the backend already collapses to
/// `style_blueprint_1` — fall back to the first screen rather than stranding
/// the user.
String routeForNextStep(String? nextStep) =>
    _nextStepRoutes[nextStep] ?? BlueprintIdentityScreen.name;
