import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/analytics/analytics_service.dart';

/// The app-wide analytics sink.
///
/// Currently always the debug/log implementation. When the PostHog project
/// key lands (BE 2.3), select the real implementation here by key presence:
///
///   const key = String.fromEnvironment('POSTHOG_API_KEY');
///   return key.isEmpty ? DebugAnalyticsService() : PosthogAnalyticsService();
final analyticsProvider = Provider<AnalyticsService>((ref) {
  return DebugAnalyticsService();
});
