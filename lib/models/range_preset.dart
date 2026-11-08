import 'package:flutter/material.dart';

/// Relative chart windows that always end at the current time.
enum RangePreset {
  lastHour(Duration(hours: 1)),
  last24Hours(Duration(hours: 24)),
  last7Days(Duration(days: 7)),
  last30Days(Duration(days: 30));

  final Duration duration;
  const RangePreset(this.duration);

  DateTimeRange rangeEndingAt(DateTime end) =>
      DateTimeRange(start: end.subtract(duration), end: end);

  static RangePreset? tryParse(dynamic value) {
    for (final p in values) {
      if (p.name == value) return p;
    }
    return null;
  }
}
