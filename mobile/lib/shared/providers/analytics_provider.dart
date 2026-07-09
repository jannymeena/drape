import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics/analytics_service.dart';
import '../services/analytics/posthog_analytics_service.dart';

/// The app-wide analytics sink.
///
/// Selected by key presence: a `--dart-define=POSTHOG_API_KEY=...` build gets
/// the real PostHog sink, everything else (dev, tests, keyless release) gets
/// the debug/log sink so nothing leaves the device. The native SDK for the
/// PostHog path is initialised in `main` via
/// `PosthogAnalyticsService.ensureInitialized()` before the first `capture`.
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return PosthogAnalyticsService.isConfigured
      ? PosthogAnalyticsService()
      : DebugAnalyticsService();
});
