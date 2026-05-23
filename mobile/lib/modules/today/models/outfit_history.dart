/// Mirrors the backend `OutfitHistoryResponse` / `HistoryEntry` /
/// `HistoryStreak` (`app/schemas/outfit.py`), returned by
/// `GET /outfits/history?filter=`.
///
/// Only *logged* outfits land here, so every entry is "worn" (there is no
/// skipped state on the wire). Date label helpers are hand-rolled because the
/// app doesn't depend on `intl`.
library;

import 'outfit.dart';

/// The backend's `HistoryFilter` literals. Index order matches the chip row in
/// [OutfitHistoryScreen]; [query] is the value sent to the API.
enum HistoryFilter {
  thisWeek('this_week', 'This Week'),
  thisMonth('this_month', 'This Month'),
  last3Months('last_3_months', 'Last 3 Months'),
  all('all', 'All Time');

  const HistoryFilter(this.query, this.label);

  final String query;
  final String label;
}

class HistoryStreak {
  const HistoryStreak({
    required this.days,
    required this.isActive,
    this.startedAt,
  });

  final int days;
  final bool isActive;
  final DateTime? startedAt;

  factory HistoryStreak.fromJson(Map<String, dynamic> json) {
    return HistoryStreak(
      days: json['days'] as int? ?? 0,
      isActive: json['is_active'] as bool? ?? false,
      startedAt: json['started_at'] == null
          ? null
          : DateTime.parse(json['started_at'] as String),
    );
  }
}

class HistoryEntry {
  const HistoryEntry({
    required this.outfitId,
    required this.loggedAt,
    required this.occasion,
    required this.itemsCount,
    required this.wornCount,
    required this.items,
    this.imageUrl,
  });

  final String outfitId;
  final DateTime loggedAt;
  final String occasion; // backend literal: work | casual | gym | date_night | other
  final int itemsCount;
  final int wornCount;
  final String? imageUrl;
  final List<OutfitItem> items;

  /// `date_night` → "Date Night".
  String get occasionLabel => occasion
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  /// "April 2026" (local time) — used to group entries under a month header.
  String get monthLabel {
    final d = loggedAt.toLocal();
    return '${_months[d.month - 1]} ${d.year}';
  }

  /// "Sunday, April 12" (local time).
  String get dayLabel {
    final d = loggedAt.toLocal();
    return '${_weekdays[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day}';
  }

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      outfitId: json['outfit_id'] as String,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      occasion: json['occasion'] as String,
      itemsCount: json['items_count'] as int? ?? 0,
      wornCount: json['worn_count'] as int? ?? 0,
      imageUrl: json['image_url'] as String?,
      items: (json['items'] as List<dynamic>? ?? const [])
          .map((e) => OutfitItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class OutfitHistory {
  const OutfitHistory({
    required this.outfits,
    required this.totalCount,
    required this.currentStreak,
    required this.filter,
  });

  final List<HistoryEntry> outfits;
  final int totalCount;
  final HistoryStreak currentStreak;
  final String filter;

  bool get isEmpty => outfits.isEmpty;

  /// Entries grouped by [HistoryEntry.monthLabel], preserving the backend's
  /// newest-first order both across and within groups.
  Map<String, List<HistoryEntry>> groupedByMonth() {
    final groups = <String, List<HistoryEntry>>{};
    for (final entry in outfits) {
      groups.putIfAbsent(entry.monthLabel, () => []).add(entry);
    }
    return groups;
  }

  factory OutfitHistory.fromJson(Map<String, dynamic> json) {
    return OutfitHistory(
      outfits: (json['outfits'] as List<dynamic>? ?? const [])
          .map((e) => HistoryEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int? ?? 0,
      currentStreak: HistoryStreak.fromJson(
          json['current_streak'] as Map<String, dynamic>? ?? const {}),
      filter: json['filter'] as String? ?? 'all',
    );
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _weekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
