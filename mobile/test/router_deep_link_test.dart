import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/modules/today/models/outfit_reasoning.dart';
import 'package:mobile/modules/today/screens/ai_reasoning_detail_screen.dart';
import 'package:mobile/modules/today/today_controller.dart';
import 'package:mobile/modules/today/today_service.dart';
import 'package:mobile/modules/wardrobe/models/wardrobe_item.dart';
import 'package:mobile/modules/wardrobe/screens/item_detail_screen.dart';
import 'package:mobile/modules/wardrobe/wardrobe_service.dart';
import 'package:mobile/shared/providers/router_provider.dart';
import 'package:mobile/shared/services/analytics/analytics_service.dart';
import 'package:mobile/shared/services/dashboard_cache.dart';
import 'package:mobile/shared/services/session_store.dart';

/// A Today controller that never touches the network, so building the Today
/// branch (which the reasoning deep link sits under) doesn't fire a real
/// dashboard fetch during these routing-only tests.
class _StubTodayController extends TodayController {
  _StubTodayController()
      : super(TodayService(Dio()), DashboardCache(), DebugAnalyticsService());
  @override
  Future<void> loadFrame() async {}
}

/// A wardrobe service that returns canned data instantly, so the wardrobe
/// branch (list + the deep-linked detail) doesn't fire real network calls —
/// the list controller's load and `wardrobeItemProvider` both resolve fast.
class _FakeWardrobeService extends WardrobeService {
  _FakeWardrobeService() : super(Dio());

  @override
  Future<WardrobeListResult> getItems({
    String? category,
    bool? isFavorite,
    bool? isStarter,
    int limit = 50,
    int offset = 0,
  }) async =>
      const WardrobeListResult(items: [], total: 0, limit: 50, offset: 0);

  @override
  Future<WardrobeItem> getItem(String itemId) async => WardrobeItem(
        id: itemId,
        name: 'Stub Item',
        category: 'tops',
        wornCount: 0,
        isFavorite: false,
        isStarterWardrobe: false,
        addedVia: 'manual',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
}

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
    final container = ProviderContainer(
      overrides: [
        wardrobeServiceProvider.overrideWithValue(_FakeWardrobeService()),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(routerProvider);

    router.go('/wardrobe/items/abc-123');
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    final detail = tester.widget<ItemDetailScreen>(find.byType(ItemDetailScreen));
    expect(detail.itemId, 'abc-123');
  });

  testWidgets(
    'Deep link /today/outfit/mock-1/reasoning resolves with outfitId="mock-1"',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          todayControllerProvider.overrideWith((ref) => _StubTodayController()),
          // The reasoning screen now fetches on build; hand it a canned result
          // so the loading spinner resolves and this routing-only test settles.
          outfitReasoningProvider.overrideWith(
            (ref, outfitId) => const OutfitReasoning(
              outfitId: 'mock-1',
              items: [],
              compatibilityLabel: 'High compatibility',
              factors: [],
              fullText: 'Stubbed reasoning.',
              compatibilityScore: 90,
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(routerProvider);

      router.go('/today/outfit/mock-1/reasoning');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      final detail = tester
          .widget<AiReasoningDetailScreen>(find.byType(AiReasoningDetailScreen));
      expect(detail.outfitId, 'mock-1');
    },
  );
}
