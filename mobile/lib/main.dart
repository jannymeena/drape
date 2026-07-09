import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/services/analytics/posthog_analytics_service.dart';
import 'shared/services/crash/sentry_crash_reporter.dart';
import 'shared/services/session_store.dart';

Future<void> main() async {
  // Wrap the whole boot in Sentry's guarded zone (a no-op passthrough without a
  // SENTRY_DSN) so uncaught errors from startup and the running app are
  // reported. Binding init, session hydration, and analytics setup all run
  // inside the zone so their failures are captured too.
  await SentryCrashReporter.runWithReporting(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Hydrate the session flag before the router's first redirect runs.
    await SessionStore.load();
    // No-op unless POSTHOG_API_KEY was passed at build time; must run before the
    // first capture so the keyed sink has an initialised native SDK.
    await PosthogAnalyticsService.ensureInitialized();
    runApp(const ProviderScope(child: DrapeApp()));
  });
}
