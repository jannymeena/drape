/// Crash + error reporting sink (MOBILE_CHANGES P4).
///
/// Same provider shape as `AnalyticsService`: one interface, per-env
/// implementations, selected by key presence. [SentryCrashReporter] is chosen
/// when a `SENTRY_DSN` is injected at build time; otherwise [NoopCrashReporter]
/// is used and nothing leaves the device (uncaught errors still surface through
/// Flutter's default handler in the console).
///
/// Global uncaught Flutter/Dart errors are captured automatically by the Sentry
/// zone set up in `main` — this interface is the *manual* surface: attributing
/// reports to a user and reporting caught-but-notable errors.
abstract class CrashReporter {
  /// Reports a caught error that the app decided not to swallow silently.
  /// Uncaught errors need no call here — the Sentry zone captures those.
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false});

  /// Attributes subsequent reports to the signed-in user. Called on
  /// login/signup/bootstrap with the backend user id (a UUID — never email or
  /// any other PII, same rule as analytics `identify`).
  void setUser(String userId);

  /// Drops the user attribution on logout, so a crash from a next account on
  /// this device is never tagged with the previous user's id.
  void clearUser();
}

/// No-DSN sink: every method is a no-op. Selected in dev, tests, and any
/// keyless release build — nothing is sent off-device.
class NoopCrashReporter implements CrashReporter {
  const NoopCrashReporter();

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stack, {
    bool fatal = false,
  }) async {}

  @override
  void setUser(String userId) {}

  @override
  void clearUser() {}
}
