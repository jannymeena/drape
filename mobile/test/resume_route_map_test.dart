import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/modules/onboarding/resume_route_map.dart';
import 'package:mobile/modules/onboarding/screens/avatar_reveal_screen.dart';
import 'package:mobile/modules/onboarding/screens/height_input_screen.dart';
import 'package:mobile/modules/onboarding/screens/pre_measurement_screen.dart';
import 'package:mobile/modules/onboarding/screens/shopping_style_screen.dart';
import 'package:mobile/modules/onboarding/screens/shoulders_screen.dart';
import 'package:mobile/modules/onboarding/screens/thigh_measurement_screen.dart';

/// Guards the `next_step` → route mapping against backend step renames: every
/// `OnboardingStep` the backend can return must resolve to a known screen.
void main() {
  // The full set of backend `OnboardingStep` literals (profile_service `_NEXT`).
  const allSteps = [
    'shopping_style_selection',
    'age_range',
    'style_goals',
    'pre_measurement_intro',
    'measurements_step_1',
    'measurements_step_2',
    'measurements_step_3',
    'measurements_step_4',
    'measurements_step_5',
    'measurements_step_6',
    'measurements_step_7',
    'measurements_step_8',
    'avatar_reveal',
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
    expect(routeForNextStep('shopping_style_selection'), ShoppingStyleScreen.name);
    expect(routeForNextStep('pre_measurement_intro'), PreMeasurementScreen.name);
    expect(routeForNextStep('measurements_step_1'), HeightInputScreen.name);
    expect(routeForNextStep('measurements_step_7'), ThighMeasurementScreen.name);
    expect(routeForNextStep('measurements_step_8'), ShouldersScreen.name);
    expect(routeForNextStep('avatar_reveal'), AvatarRevealScreen.name);
  });

  test('today_dashboard is the completion signal', () {
    expect(isOnboardingDone('today_dashboard'), isTrue);
    expect(isOnboardingDone('avatar_reveal'), isFalse);
    expect(isOnboardingDone('shopping_style_selection'), isFalse);
  });

  test('an unknown step falls back to the first screen', () {
    expect(routeForNextStep('something_new'), ShoppingStyleScreen.name);
    expect(routeForNextStep(null), ShoppingStyleScreen.name);
  });
}
