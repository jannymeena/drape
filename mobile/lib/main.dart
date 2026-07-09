import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/services/analytics/posthog_analytics_service.dart';
import 'shared/services/session_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Hydrate the session flag before the router's first redirect runs.
  await SessionStore.load();
  // No-op unless POSTHOG_API_KEY was passed at build time; must run before the
  // first capture so the keyed sink has an initialised native SDK.
  await PosthogAnalyticsService.ensureInitialized();
  runApp(const ProviderScope(child: DrapeApp()));
}
