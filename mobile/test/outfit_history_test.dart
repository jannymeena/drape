import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/modules/today/models/outfit_history.dart';

/// Parses a representative `GET /outfits/history` payload (shape from
/// `OutfitHistoryResponse`) and exercises the month-grouping + label helpers.
void main() {
  Map<String, dynamic> entry(String id, String loggedAt, String occasion) => {
        'outfit_id': id,
        'logged_at': loggedAt,
        'occasion': occasion,
        'items_count': 3,
        'worn_count': 1,
        'image_url': null,
        'items': [
          {'item_id': 'i1', 'name': 'Wool Blazer', 'category': 'top'},
          {'item_id': 'i2', 'name': 'Loafers', 'category': 'shoes'},
        ],
      };

  test('parses entries, streak, and filter', () {
    final h = OutfitHistory.fromJson({
      'outfits': [
        entry('a', '2026-04-12T10:00:00Z', 'date_night'),
        entry('b', '2026-04-11T10:00:00Z', 'work'),
      ],
      'total_count': 2,
      'current_streak': {
        'days': 14,
        'started_at': '2026-03-30',
        'is_active': true,
      },
      'filter': 'this_month',
    });

    expect(h.outfits, hasLength(2));
    expect(h.totalCount, 2);
    expect(h.filter, 'this_month');
    expect(h.currentStreak.days, 14);
    expect(h.currentStreak.isActive, isTrue);
    expect(h.currentStreak.startedAt, DateTime.parse('2026-03-30'));
    // `date_night` → "Date Night"; items list survives.
    expect(h.outfits.first.occasionLabel, 'Date Night');
    expect(h.outfits.first.items.first.name, 'Wool Blazer');
  });

  test('groupedByMonth keys by month label, preserving order', () {
    final h = OutfitHistory.fromJson({
      'outfits': [
        entry('a', '2026-04-12T10:00:00Z', 'work'),
        entry('b', '2026-04-11T10:00:00Z', 'work'),
        entry('c', '2026-03-31T10:00:00Z', 'casual'),
      ],
      'total_count': 3,
      'current_streak': {'days': 0, 'is_active': false},
      'filter': 'all',
    });

    final groups = h.groupedByMonth();
    expect(groups.keys.toList(), ['April 2026', 'March 2026']);
    expect(groups['April 2026'], hasLength(2));
    expect(groups['March 2026'], hasLength(1));
  });

  test('empty history reports isEmpty and a null streak start', () {
    final h = OutfitHistory.fromJson({
      'outfits': <dynamic>[],
      'total_count': 0,
      'current_streak': {'days': 0, 'is_active': false},
      'filter': 'this_week',
    });

    expect(h.isEmpty, isTrue);
    expect(h.currentStreak.startedAt, isNull);
    expect(h.groupedByMonth(), isEmpty);
  });
}
