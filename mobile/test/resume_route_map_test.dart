import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/modules/onboarding/resume_route_map.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_aesthetics_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_goals_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_identity_screen.dart';
import 'package:mobile/modules/onboarding/screens/blueprint_reveal_screen.dart';

/// Guards the `next_step` → route mapping against backend step renames: every
/// `OnboardingStep` the backend can return must resolve to a known screen.
void main() {
  // The full set of backend `OnboardingStep` literals (profile_service `_NEXT`).
  const allSteps = [
    'style_blueprint_1',
    'style_blueprint_2',
    'style_blueprint_3',
    'style_blueprint_4',
    'style_blueprint_5',
    'style_blueprint_6',
    'style_blueprint_7',
    'style_blueprint_reveal',
    'today_dashboard',
  ];

  test('every onboarding step resolves (done → Today, others → a screen)', () {
    for (final step in allSteps) {
      if (isOnboardingDone(step)) continue;
      // A real onboarding screen, never the default fallback for a known step.
      expect(routeForNextStep(step), isNotEmpty);
    }
  });

  test('specific steps map to the expected screens', () {
    expect(routeForNextStep('style_blueprint_1'), BlueprintIdentityScreen.name);
    expect(
      routeForNextStep('style_blueprint_3'),
      BlueprintAestheticsScreen.name,
    );
    expect(routeForNextStep('style_blueprint_7'), BlueprintGoalsScreen.name);
    expect(
      routeForNextStep('style_blueprint_reveal'),
      BlueprintRevealScreen.name,
    );
  });

  test('today_dashboard is the completion signal', () {
    expect(isOnboardingDone('today_dashboard'), isTrue);
    expect(isOnboardingDone('style_blueprint_reveal'), isFalse);
    expect(isOnboardingDone('style_blueprint_1'), isFalse);
  });

  test('an unknown step falls back to the first screen', () {
    // Includes the pre-redesign step names: the backend already collapses
    // those to style_blueprint_1, and the client must not strand on one.
    expect(
      routeForNextStep('shopping_style_selection'),
      BlueprintIdentityScreen.name,
    );
    expect(routeForNextStep('measurements_step_4'), BlueprintIdentityScreen.name);
    expect(routeForNextStep('something_new'), BlueprintIdentityScreen.name);
    expect(routeForNextStep(null), BlueprintIdentityScreen.name);
  });
}
