import 'package:flutter/foundation.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics_service.dart';

/// PostHog-backed [AnalyticsService] (MOBILE_CHANGES P1).
///
/// Selected over [DebugAnalyticsService] only when a project key is injected at
/// build time (`--dart-define=POSTHOG_API_KEY=phc_...`); see [isConfigured] and
/// `analytics_provider.dart`. Dev and default builds ship no key, so nothing
/// leaves the device.
///
/// The native SDK must be initialised once before `runApp` via
/// [ensureInitialized] (called from `main`) — `capture`/`identify`/`reset` here
/// just forward to the already-configured `Posthog()` singleton.
class PosthogAnalyticsService implements AnalyticsService {
  /// PostHog project API key, injected at build time. Empty in dev/default
  /// builds, which keeps [DebugAnalyticsService] selected instead.
  static const _apiKey = String.fromEnvironment('POSTHOG_API_KEY');

  /// Ingestion host. US cloud by default; override for EU/self-host with
  /// `--dart-define=POSTHOG_HOST=https://eu.i.posthog.com`.
  static const _host = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://us.i.posthog.com',
  );

  /// True when a project key is present — the sole selection signal, mirroring
  /// the key-presence gating of `FeatureFlags.googleServerClientId`.
  static bool get isConfigured => _apiKey.isNotEmpty;

  /// Initialises the native PostHog SDK exactly once, before `runApp`. No-op
  /// when no key is configured (the debug sink is used instead). We init in
  /// Dart rather than via the Android/iOS manifests so the key stays a
  /// build-time dart-define — native manifest wiring is deferred to release
  /// prep (verify against tbd).
  static Future<void> ensureInitialized() async {
    if (!isConfigured) return;
    final config = PostHogConfig(_apiKey)
      ..host = _host
      // Console-log the queue while verifying a keyed debug build; silent in
      // release. personProfiles defaults to identifiedOnly and sessionReplay
      // to false — both required for PIPEDA (no anonymous profiles, no screen
      // capture); we rely on those defaults rather than restating them.
      ..debug = kDebugMode;
    await Posthog().setup(config);
  }

  @override
  void capture(String event, [Map<String, Object?> properties = const {}]) {
    Posthog().capture(
      eventName: event,
      properties: _nonNull(properties),
    );
  }

  @override
  void identify(String userId) {
    Posthog().identify(userId: userId);
  }

  @override
  void reset() {
    Posthog().reset();
  }

  /// PostHog's `capture` rejects null property values; the [AnalyticsService]
  /// contract allows them, so drop nulls (an absent property reads the same as
  /// a null one in PostHog). Returns null when nothing survives, so we don't
  /// send an empty map.
  static Map<String, Object>? _nonNull(Map<String, Object?> properties) {
    if (properties.isEmpty) return null;
    final out = <String, Object>{};
    properties.forEach((key, value) {
      if (value != null) out[key] = value;
    });
    return out.isEmpty ? null : out;
  }
}
