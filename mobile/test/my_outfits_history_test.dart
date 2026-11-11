import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/my_outfits/history_months.dart';
import 'package:mobile/modules/my_outfits/screens/my_outfits_screen.dart';
import 'package:mobile/modules/today/models/outfit_history.dart';
import 'package:mobile/modules/today/today_service.dart';

const _monthNames = [
  'JANUARY', 'FEBRUARY', 'MARCH', 'APRIL', 'MAY', 'JUNE', //
  'JULY', 'AUGUST', 'SEPTEMBER', 'OCTOBER', 'NOVEMBER', 'DECEMBER',
];

DateTime _daysAgo(int n, {int hour = 9}) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day - n, hour);
}

HistoryEntry _entry(String id, DateTime at, {Map<String, dynamic>? extra}) =>
    HistoryEntry.fromJson({
      'outfit_id': id,
      'logged_at': at.toUtc().toIso8601String(),
      'occasion': 'work',
      'items_count': 4,
      'worn_count': 1,
      'items': [
        {'item_id': '$id-1', 'name': 'Wool Blazer', 'category': 'outerwear'},
        {'item_id': '$id-2', 'name': 'Loafers', 'category': 'shoes'},
        {'item_id': '$id-3', 'name': 'Chinos', 'category': 'bottoms'},
        {'item_id': '$id-4', 'name': 'Oxford', 'category': 'tops'},
      ],
      ...?extra,
    });

void main() {
  group('buildHistoryMonths', () {
    test('fills skipped days between the first log and yesterday', () {
      final now = DateTime.now();
      final months = buildHistoryMonths(
        [_entry('a', _daysAgo(1)), _entry('b', _daysAgo(4))],
        now: now,
      );
      final rows = [for (final m in months) ...m.rows];
      // a (1 day ago), skipped 2 + 3, b (4 days ago) — newest first.
      expect(rows.map((r) => r.runtimeType).toList(), [
        WornRow,
        SkippedRow,
        SkippedRow,
        WornRow,
      ]);
      expect(rows.whereType<SkippedRow>().map((r) => r.day), [
        DateTime(now.year, now.month, now.day - 2),
        DateTime(now.year, now.month, now.day - 3),
      ]);
      expect(months.fold(0, (n, m) => n + m.worn), 2);
      expect(months.fold(0, (n, m) => n + m.skipped), 2);
    });

    test('today without a log is not skipped; no logs, no rows', () {
      expect(
        buildHistoryMonths([_entry('a', _daysAgo(0))], now: DateTime.now())
            .single
            .skipped,
        0,
      );
      expect(buildHistoryMonths(const [], now: DateTime.now()), isEmpty);
    });

    test('labels months in capitals, newest month first', () {
      final months = buildHistoryMonths(
        [_entry('a', DateTime(2026, 11, 3, 9)), _entry('b', DateTime(2026, 10, 31, 9))],
        now: DateTime(2026, 11, 4, 12),
      );
      expect(months.map((m) => m.label), ['NOVEMBER 2026', 'OCTOBER 2026']);
      expect(months.first.skipped, 2); // Nov 1, Nov 2
      expect(months.last.worn, 1);
    });
  });

  testWidgets('History tab renders streak, months, worn + skipped cards', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 3000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final worn = _daysAgo(1);
    final history = OutfitHistory.fromJson({
      'outfits': <dynamic>[],
      'total_count': 2,
      'current_streak': {'days': 14, 'is_active': true},
      'filter': 'this_week',
    });
    final withEntries = OutfitHistory(
      outfits: [
        _entry(
          'a',
          worn,
          extra: {
            'weather_context': {
              'temp_c': 8.2,
              'feels_like_c': 5.0,
              'condition': 'rain',
            },
          },
        ),
        _entry('b', _daysAgo(3)),
      ],
      totalCount: 2,
      currentStreak: history.currentStreak,
      filter: 'this_week',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          outfitHistoryProvider.overrideWith((ref, filter) async => withEntries),
        ],
        child: const MaterialApp(
          home: MyOutfitsScreen(initialTab: MyOutfitsTab.history),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    for (final chip in ['This week', 'This month', 'Last 3 months', 'All']) {
      expect(find.text(chip), findsOneWidget, reason: chip);
    }
    expect(find.text('14-day streak'), findsOneWidget);
    expect(find.text('Share'), findsOneWidget);
    expect(find.textContaining('${_monthNames[worn.month - 1]} ${worn.year}'),
        findsWidgets);
    expect(find.text('Worn'), findsNWidgets(2));
    expect(find.text('Work'), findsNWidgets(2));
    expect(find.text('4 items'), findsNWidgets(2));
    expect(find.text('Wool Blazer'), findsNWidgets(2));
    expect(find.text('+2'), findsNWidgets(2));
    expect(find.text('8°C · Rain'), findsOneWidget);
    expect(find.text('Wear again'), findsNWidgets(2));
    // The day between the two logs is skipped.
    expect(find.text('Skipped'), findsOneWidget);
    expect(find.text('Add what you wore'), findsOneWidget);
  });
}
