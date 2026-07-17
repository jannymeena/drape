import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/feature_flags.dart';
import '../services/analytics/analytics_events.dart';
import '../services/push/fcm_push_registrar.dart';
import '../services/push/push_registrar.dart';
import '../services/push/push_route_map.dart';
import 'analytics_provider.dart';
import 'network_provider.dart';
import 'router_provider.dart';

/// The app-wide push registrar.
///
/// Selected by [FeatureFlags.push] (Android-only until the APNs key lands):
/// on-platform builds get the FCM registrar wired to the shared Dio, the
/// analytics sink, and tap-through routing; everything else gets the no-op —
/// same selection pattern as the analytics and crash providers.
///
/// The auth controller drives the lifecycle: `register()` on session start,
/// `unregister()` on logout. `ensurePermission()` fires post-onboarding from
/// the Today dashboard.
final pushRegistrarProvider = Provider<PushRegistrar>((ref) {
  if (!FeatureFlags.push) return NoopPushRegistrar();
  return FcmPushRegistrar(
    dio: ref.read(dioProvider),
    analytics: ref.read(analyticsProvider),
    onNotificationOpened: (data) {
      ref.read(analyticsProvider).capture(
        AnalyticsEvents.pushNotificationTapped,
        {'route': data['route'] ?? 'none'},
      );
      final name = pushRouteNameFor(data['route']);
      if (name != null) ref.read(routerProvider).goNamed(name);
    },
  );
});
