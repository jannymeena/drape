import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/crash/crash_reporter.dart';
import '../services/crash/sentry_crash_reporter.dart';

/// The app-wide crash/error reporter.
///
/// Selected by key presence: a `--dart-define=SENTRY_DSN=...` build gets the
/// real Sentry sink, everything else (dev, tests, keyless release) gets the
/// no-op sink so nothing leaves the device. The Sentry zone that captures
/// uncaught errors is installed in `main` via
/// `SentryCrashReporter.runWithReporting()`; this provider is the manual
/// surface (`setUser`/`clearUser`/`recordError`).
final crashReporterProvider = Provider<CrashReporter>((ref) {
  return SentryCrashReporter.isConfigured
      ? SentryCrashReporter()
      : const NoopCrashReporter();
});
