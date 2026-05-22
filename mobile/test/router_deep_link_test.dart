import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/modules/today/screens/ai_reasoning_detail_screen.dart';
import 'package:mobile/modules/wardrobe/screens/item_detail_screen.dart';
import 'package:mobile/shared/providers/router_provider.dart';
import 'package:mobile/shared/services/session_store.dart';

/// Verifies the `:id` path parameters extract correctly for the two detail
/// routes wired in Phase C6. These are the deep-link entry points used by
/// both in-app navigation and (post-Phase F) external URLs.
void main() {
  // These detail routes live under the authed main shell, so the router's
  // auth gate (Phase D) needs an active session. `main()` seeds this from disk
  // at startup; tests set it directly (no platform channel involved).
  setUp(() => SessionStore.state.value = true);
  tearDown(() => SessionStore.state.value = false);

  testWidgets('Deep link /wardrobe/items/abc-123 resolves with id="abc-123"',
      (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    router.go('/wardrobe/items/abc-123');
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final detail = tester.widget<ItemDetailScreen>(find.byType(ItemDetailScreen));
    expect(detail.itemId, 'abc-123');
  });

  testWidgets(
    'Deep link /today/outfit/mock-1/reasoning resolves with outfitId="mock-1"',
    (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/today/outfit/mock-1/reasoning');
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      final detail = tester
          .widget<AiReasoningDetailScreen>(find.byType(AiReasoningDetailScreen));
      expect(detail.outfitId, 'mock-1');
    },
  );
}
