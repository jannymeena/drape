import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Client-side feature switches, mirroring the backend's `DISABLED_FEATURES`
/// (`backend/app/core/config.py`): comma-separated feature names to turn OFF,
/// passed at build time —
///
///   flutter run --dart-define=DISABLED_FEATURES=apple_login,google_login
///
/// Feature names match the backend's so one runbook covers both sides. A
/// feature that also needs a config key (Google's server client ID) is off
/// while the key is absent — the same key-presence selection planned for the
/// analytics sink (`POSTHOG_API_KEY`). Off means the control is hidden, never
/// shown dead.
class FeatureFlags {
  FeatureFlags._();

  static const _disabledRaw = String.fromEnvironment('DISABLED_FEATURES');

  /// Google OAuth server client ID (`--dart-define=GOOGLE_SERVER_CLIENT_ID`).
  /// google_sign_in mints the identity token with this as its audience, so it
  /// must equal one of the backend's `GOOGLE_CLIENT_ID` audiences or the
  /// backend rejects the token (401 `oauth_invalid_token`).
  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

  /// Grow alongside the backend's `_KNOWN_FEATURES` as switches land here.
  static const _knownFeatures = {'apple_login', 'google_login'};

  static Set<String> get _disabled {
    final names = _disabledRaw
        .split(',')
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toSet();
    // The backend fails startup on unknown names; a build-time typo here would
    // otherwise silently leave a feature on.
    assert(
      names.difference(_knownFeatures).isEmpty,
      'Unknown feature name(s) in DISABLED_FEATURES: '
      '${names.difference(_knownFeatures).join(', ')}. '
      'Known: ${_knownFeatures.join(', ')}',
    );
    return names;
  }

  static bool _enabled(String feature) => !_disabled.contains(feature);

  /// Sign in with Apple is iOS-only for v1 (Android would need the Apple web
  /// flow + a Service ID — not set up). Needs no client-side key; the Runner
  /// target's Sign in with Apple capability is part of release prep.
  static bool get appleLogin =>
      !kIsWeb && Platform.isIOS && _enabled('apple_login');

  /// Hidden until the Google client IDs arrive (MOBILE_CHANGES P2).
  static bool get googleLogin =>
      googleServerClientId.isNotEmpty && _enabled('google_login');
}
