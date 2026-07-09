import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/providers/crash_provider.dart';
import 'package:mobile/shared/services/crash/crash_reporter.dart';
import 'package:mobile/shared/services/crash/sentry_crash_reporter.dart';

/// Guards the P4 crash-reporting plumbing: the keyless fallback is the no-op
/// sink (nothing leaves the device) and its methods are safe to call.
void main() {
  test('NoopCrashReporter accepts calls without throwing', () async {
    const reporter = NoopCrashReporter();
    await reporter.recordError(StateError('boom'), StackTrace.current);
    reporter.setUser('user-id');
    reporter.clearUser();
  });

  test('provider falls back to the no-op sink with no SENTRY_DSN', () {
    // This test binary builds with no dart-defines, so the DSN is absent and
    // the Sentry sink must never be selected.
    expect(SentryCrashReporter.isConfigured, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(crashReporterProvider), isA<NoopCrashReporter>());
  });
}
