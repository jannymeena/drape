import '../today/models/outfit_history.dart';

/// One line in the History list: an outfit that was worn, or a day with
/// nothing logged.
sealed class HistoryRow {
  const HistoryRow();
  DateTime get day;
}

class WornRow extends HistoryRow {
  final HistoryEntry entry;
  const WornRow(this.entry);

  @override
  DateTime get day => entry.day;
}

class SkippedRow extends HistoryRow {
  @override
  final DateTime day;
  const SkippedRow(this.day);
}

/// "NOVEMBER 2026" with its rows and the "3 worn · 1 skipped" tally.
class HistoryMonth {
  final String label;
  final List<HistoryRow> rows;
  const HistoryMonth(this.label, this.rows);

  int get worn => rows.whereType<WornRow>().length;
  int get skipped => rows.whereType<SkippedRow>().length;
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', //
  'July', 'August', 'September', 'October', 'November', 'December',
];

/// Groups [entries] (newest first, as the backend sends them) by month and
/// fills in skipped days.
///
/// The backend only knows logged outfits, so "skipped" is worked out here:
/// any day from the first logged day in the list up to yesterday with nothing
/// logged. Days before the first log (e.g. before the user started) and today
/// (not over yet) are never counted as skipped.
List<HistoryMonth> buildHistoryMonths(
  List<HistoryEntry> entries, {
  required DateTime now,
}) {
  if (entries.isEmpty) return const [];
  final logged = {for (final e in entries) e.day};
  final first = logged.reduce((a, b) => a.isBefore(b) ? a : b);
  final today = DateTime(now.year, now.month, now.day);

  final rows = <HistoryRow>[for (final e in entries) WornRow(e)];
  for (
    var d = first;
    d.isBefore(today);
    d = DateTime(d.year, d.month, d.day + 1)
  ) {
    if (!logged.contains(d)) rows.add(SkippedRow(d));
  }
  // Newest day first; entries keep the backend's order within a day.
  final order = {for (final (i, r) in rows.indexed) r: i};
  rows.sort((a, b) {
    final byDay = b.day.compareTo(a.day);
    return byDay != 0 ? byDay : order[a]!.compareTo(order[b]!);
  });

  final months = <String, List<HistoryRow>>{};
  for (final r in rows) {
    final label = '${_months[r.day.month - 1]} ${r.day.year}'.toUpperCase();
    months.putIfAbsent(label, () => []).add(r);
  }
  return [for (final m in months.entries) HistoryMonth(m.key, m.value)];
}
