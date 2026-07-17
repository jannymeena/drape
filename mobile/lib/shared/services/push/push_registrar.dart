import 'package:flutter/foundation.dart';

/// Client half of the push framework (backend: `POST/DELETE /devices` +
/// `notify_user` fan-out). Selected by [FeatureFlags.push] in
/// `push_provider.dart`: Android gets `FcmPushRegistrar`, everything else
/// (iOS until the APNs key lands, tests, web) gets [NoopPushRegistrar] —
/// the same key/platform-presence pattern as the analytics and crash sinks.
///
/// Every method is best-effort and must never throw: push is a side channel,
/// and a failure here must not break login, bootstrap, or logout.
abstract class PushRegistrar {
  /// Registers this device's push token with the backend. Called on every
  /// session start (login, signup, launch bootstrap). Silent — token
  /// retrieval needs no OS permission, so no dialog fires here.
  Future<void> register();

  /// Shows the one-time OS notification permission prompt if it was never
  /// shown. Called post-onboarding (Today dashboard), per the product spec —
  /// never on first launch.
  Future<void> ensurePermission();

  /// Removes this device's token from the backend and stops listening.
  /// Called on logout while the session token is still valid.
  Future<void> unregister();
}

/// Keyless/off-platform sink: accepts every call, logs in debug, sends
/// nothing. Keeps callers unconditional, mirroring `DebugAnalyticsService`.
class NoopPushRegistrar implements PushRegistrar {
  @override
  Future<void> register() async {
    if (kDebugMode) debugPrint('push: register (noop)');
  }

  @override
  Future<void> ensurePermission() async {
    if (kDebugMode) debugPrint('push: ensurePermission (noop)');
  }

  @override
  Future<void> unregister() async {
    if (kDebugMode) debugPrint('push: unregister (noop)');
  }
}
