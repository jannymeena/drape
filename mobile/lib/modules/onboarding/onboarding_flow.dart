import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../shared/models/api_error.dart';
import 'onboarding_controller.dart';
import 'screens/wardrobe_setup_screen.dart';
import 'widgets/save_progress_sheet.dart';

/// Shared "Skip for now / Finish later" handler for the measurement screens.
///
/// The backend requires all body measurements in a single call, so there's no
/// such thing as a partial submit — skipping means "pause and finish later in
/// your profile". This confirms via the save-progress dialog, records the pause
/// point with the backend (best-effort), then exits the measurement block into
/// wardrobe setup. [step] is the current screen's `OnboardingStep` literal.
Future<void> confirmSkipMeasurements(
  BuildContext context,
  WidgetRef ref, {
  required String step,
}) async {
  final exit = await showSaveProgressDialog(context);
  if (!exit || !context.mounted) return;
  try {
    await ref.read(onboardingControllerProvider.notifier).saveProgress(step);
  } on ApiException {
    // Best-effort: a failed save must not trap the user in onboarding.
  }
  if (context.mounted) context.goNamed(WardrobeSetupScreen.name);
}
