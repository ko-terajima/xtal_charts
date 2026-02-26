/// A single entry for a calendar heatmap.
/// Used when building a Map from a list via the [CalendarHeatmapData.fromEntries] factory.
class CalendarHeatmapEntry {
  final DateTime date;
  final double value;

  const CalendarHeatmapEntry({required this.date, required this.value});
}

/// Data model for a calendar heatmap.
///
/// Holds per-date values as a `Map<DateTime, double>`.
/// DateTime keys contain only year, month, and day (time is ignored).
///
/// ```dart
/// final data = CalendarHeatmapData.fromEntries(
///   entries: [
///     CalendarHeatmapEntry(date: DateTime(2025, 12, 1), value: 10),
///     CalendarHeatmapEntry(date: DateTime(2025, 12, 15), value: 25),
///   ],
/// );
/// ```
class CalendarHeatmapData {
  /// Date-to-value mapping. Keys are normalized to `DateTime(year, month, day)`.
  final Map<DateTime, double> values;

  const CalendarHeatmapData({required this.values});

  /// Returns the value for the given date, or null if no data exists.
  /// Looks up by year, month, and day only, ignoring time.
  double? valueOf(DateTime date) {
    final normalizedKey = DateTime(date.year, date.month, date.day);
    return values[normalizedKey];
  }

  /// Minimum value in the data. Returns 0 if empty.
  double get minValue {
    if (values.isEmpty) return 0;
    return values.values.reduce((a, b) => a < b ? a : b);
  }

  /// Maximum value in the data. Returns 1 if empty.
  double get maxValue {
    if (values.isEmpty) return 1;
    return values.values.reduce((a, b) => a > b ? a : b);
  }

  /// Constructs from a flat list of [CalendarHeatmapEntry].
  /// Useful for converting row-based data from Supabase RPC results, etc.
  /// If duplicate dates exist, the last entry wins.
  factory CalendarHeatmapData.fromEntries({
    required List<CalendarHeatmapEntry> entries,
  }) {
    final map = <DateTime, double>{};
    for (final entry in entries) {
      final key = DateTime(entry.date.year, entry.date.month, entry.date.day);
      map[key] = entry.value;
    }
    return CalendarHeatmapData(values: map);
  }
}
