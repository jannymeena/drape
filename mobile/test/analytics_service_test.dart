import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/providers/analytics_provider.dart';
import 'package:mobile/shared/services/analytics/analytics_service.dart';
import 'package:mobile/shared/services/analytics/posthog_analytics_service.dart';
import 'package:mobile/shared/widgets/analytics_screen_view.dart';

/// Guards the P1 analytics plumbing: the default sink is safe to call, and
/// AnalyticsScreenView fires its event exactly once per mount (not per build).
class _RecordingAnalytics implements AnalyticsService {
  final events = <(String, Map<String, Object?>)>[];
  final identified = <String>[];
  int resets = 0;

  @override
  void capture(String event, [Map<String, Object?> properties = const {}]) {
    events.add((event, properties));
  }

  @override
  void identify(String userId) => identified.add(userId);

  @override
  void reset() => resets++;
}

void main() {
  test('DebugAnalyticsService accepts calls without throwing', () {
    final analytics = DebugAnalyticsService();
    analytics.capture('event_name', {'key': 'value'});
    analytics.capture('bare_event');
    analytics.identify('user-id');
    analytics.reset();
  });

  test('provider falls back to the debug sink with no POSTHOG_API_KEY', () {
    // This test binary builds with no dart-defines, so the key is absent and
    // the PostHog sink must never be selected (nothing leaves the device).
    expect(PosthogAnalyticsService.isConfigured, isFalse);

    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(analyticsProvider), isA<DebugAnalyticsService>());
  });

  testWidgets('AnalyticsScreenView captures once, not on rebuild',
      (tester) async {
    final recorder = _RecordingAnalytics();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [analyticsProvider.overrideWithValue(recorder)],
        child: const MaterialApp(
          home: AnalyticsScreenView(
            event: 'screen_viewed',
            properties: {'source': 'test'},
            child: _Rebuilder(),
          ),
        ),
      ),
    );
    expect(recorder.events.length, 1);
    expect(recorder.events.single.$1, 'screen_viewed');
    expect(recorder.events.single.$2, {'source': 'test'});

    // Force a rebuild of the subtree — the event must not fire again.
    await tester.tap(find.text('rebuild'));
    await tester.pump();
    expect(recorder.events.length, 1);
  });
}

class _Rebuilder extends StatefulWidget {
  const _Rebuilder();

  @override
  State<_Rebuilder> createState() => _RebuilderState();
}

class _RebuilderState extends State<_Rebuilder> {
  int _n = 0;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () => setState(() => _n++),
      child: Text('rebuild', key: ValueKey(_n)),
    );
  }
}
