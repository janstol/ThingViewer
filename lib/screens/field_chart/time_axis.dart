const _steps = [
  Duration(minutes: 1),
  Duration(minutes: 2),
  Duration(minutes: 5),
  Duration(minutes: 10),
  Duration(minutes: 15),
  Duration(minutes: 30),
  Duration(hours: 1),
  Duration(hours: 2),
  Duration(hours: 3),
  Duration(hours: 6),
  Duration(hours: 12),
  Duration(days: 1),
  Duration(days: 2),
  Duration(days: 7),
  Duration(days: 14),
  Duration(days: 30),
  Duration(days: 60),
  Duration(days: 90),
  Duration(days: 180),
  Duration(days: 365),
];

/// The smallest round step (minutes, hours, days) that keeps the number of time-axis labels across [span] at or below [maxLabels].
Duration timeAxisInterval(Duration span, int maxLabels) {
  final limit = maxLabels < 1 ? 1 : maxLabels;
  for (final step in _steps) {
    if (span.inMilliseconds / step.inMilliseconds <= limit) return step;
  }
  final years = (span.inDays / 365 / limit).ceil();
  return Duration(days: 365 * years);
}

/// Whether labels spaced [interval] apart should show the time of day rather than the date.
bool timeAxisShowsTime(Duration interval) => interval < const Duration(days: 1);

/// Label text for a time-axis tick at [dt]. Ticks closer together than a day show the time, except at local midnight, where the date tells the reader that the day changed.
String timeAxisLabel(
  DateTime dt,
  Duration interval, {
  required String Function(DateTime) formatDate,
  required String Function(DateTime) formatTime,
}) {
  if (!timeAxisShowsTime(interval)) {
    // Day ticks are aligned to one UTC offset, so across a DST change they sit an hour off midnight. Labelling the nearest midnight keeps the date right.
    return formatDate(
      DateTime(dt.year, dt.month, dt.day + (dt.hour >= 12 ? 1 : 0)),
    );
  }
  final isMidnight = dt.hour == 0 && dt.minute == 0;
  return isMidnight ? formatDate(dt) : formatTime(dt);
}
