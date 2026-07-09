import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'crash_reporter.dart';

/// Sentry-backed [CrashReporter] (MOBILE_CHANGES P4).
///
/// Selected over [NoopCrashReporter] only when a DSN is injected at build time
/// (`--dart-define=SENTRY_DSN=https://...`); see [isConfigured] and
/// `crash_provider.dart`. Unlike Firebase Crashlytics, Sentry needs no native
/// config files — the DSN in Dart is enough — which is why it clears the
/// native-config wall that blocks push (MOBILE_CHANGES P3).
class SentryCrashReporter implements CrashReporter {
  /// Sentry DSN, injected at build time. Empty in dev/default builds, which
  /// keeps [NoopCrashReporter] selected instead — the same key-presence gating
  /// as `PosthogAnalyticsService` and the OAuth flags.
  static const _dsn = String.fromEnvironment('SENTRY_DSN');

  /// Deployment tag shown on every event. Freeform; defaults by build mode so
  /// release crashes don't mix with debug noise. Override per backend target
  /// with `--dart-define=SENTRY_ENVIRONMENT=tbd`.
  static const _environment = String.fromEnvironment(
    'SENTRY_ENVIRONMENT',
    defaultValue: kReleaseMode ? 'release' : 'debug',
  );

  static bool get isConfigured => _dsn.isNotEmpty;

  /// Runs [appRunner] (which calls `runApp`) inside Sentry's guarded zone so
  /// every uncaught Flutter/Dart error is reported. When no DSN is configured
  /// this just awaits [appRunner] in the root zone — identical startup to
  /// before Sentry, nothing initialised. Call from `main`.
  static Future<void> runWithReporting(
    Future<void> Function() appRunner,
  ) async {
    if (!isConfigured) {
      await appRunner();
      return;
    }
    await SentryFlutter.init(
      (options) {
        options.dsn = _dsn;
        options.environment = _environment;
        options.debug = kDebugMode;
        // PIPEDA: never attach IPs, request bodies, screenshots, or the view
        // hierarchy. sendDefaultPii/attachScreenshot default to false; set the
        // PII one explicitly so the intent survives an SDK default change.
        options.sendDefaultPii = false;
        // Crash-and-error reporting only — no performance tracing in v1.
        options.tracesSampleRate = 0.0;
      },
      appRunner: appRunner,
    );
  }

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {
    await Sentry.captureException(error, stackTrace: stack);
  }

  @override
  void setUser(String userId) {
    Sentry.configureScope((scope) => scope.setUser(SentryUser(id: userId)));
  }

  @override
  void clearUser() {
    Sentry.configureScope((scope) => scope.setUser(null));
  }
}
