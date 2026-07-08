import 'package:flutter/foundation.dart';

/// Product analytics sink (MOBILE_CHANGES P1).
///
/// Same shape as the backend provider pattern: one interface, per-env
/// implementations. Today only [DebugAnalyticsService] exists; when the
/// PostHog project key arrives, a `PosthogAnalyticsService` implements this
/// and `analyticsProvider` selects it by key presence — no call site changes.
///
/// Event names live exclusively in `analytics_events.dart`; call sites never
/// pass string literals.
abstract class AnalyticsService {
  /// Records one event. [properties] must already be JSON-encodable and must
  /// never contain PII or raw measurements (PIPEDA — coarse categories only,
  /// same rule as the backend prompt policy).
  void capture(String event, [Map<String, Object?> properties = const {}]);

  /// Associates subsequent events with the signed-in user. Called on
  /// login/signup/bootstrap with the backend user id (a UUID — no email).
  void identify(String userId);

  /// Drops the identity association on logout, so events from a next account
  /// on this device are never attributed to the previous one.
  void reset();
}

/// Dev/no-key sink: prints events to the debug console and otherwise drops
/// them. Also the release-build fallback while no analytics key is configured
/// (capture is then a no-op — nothing leaves the device).
class DebugAnalyticsService implements AnalyticsService {
  @override
  void capture(String event, [Map<String, Object?> properties = const {}]) {
    if (kDebugMode) {
      debugPrint(
        'analytics: $event${properties.isEmpty ? '' : ' $properties'}',
      );
    }
  }

  @override
  void identify(String userId) {
    if (kDebugMode) debugPrint('analytics: identify $userId');
  }

  @override
  void reset() {
    if (kDebugMode) debugPrint('analytics: reset');
  }
}
