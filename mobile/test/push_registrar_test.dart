import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/shared/config/feature_flags.dart';
import 'package:mobile/shared/providers/push_provider.dart';
import 'package:mobile/shared/services/push/push_registrar.dart';
import 'package:mobile/shared/services/push/push_route_map.dart';

void main() {
  group('pushRouteNameFor', () {
    test('maps the backend paywall literal to the compare-plans route', () {
      expect(pushRouteNameFor('paywall'), 'profile_compare_plans');
    });

    test('unknown, null, and non-string routes resolve to null (no-op tap)',
        () {
      expect(pushRouteNameFor('not-a-route'), isNull);
      expect(pushRouteNameFor(null), isNull);
      expect(pushRouteNameFor(42), isNull);
    });
  });

  group('push wiring', () {
    test('provider falls back to the no-op registrar off-platform', () {
      // Tests run on the host VM (not Android), so the platform gate is off —
      // same guarantee that keeps iOS on the no-op until the APNs key lands.
      expect(FeatureFlags.push, isFalse);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(pushRegistrarProvider), isA<NoopPushRegistrar>());
    });

    test('NoopPushRegistrar accepts the full lifecycle without throwing',
        () async {
      final registrar = NoopPushRegistrar();
      await registrar.register();
      await registrar.ensurePermission();
      await registrar.unregister();
    });
  });
}
