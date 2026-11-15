import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/screens/field_chart/time_axis.dart';

void main() {
  group('timeAxisInterval', () {
    test('picks round steps that fit six labels for each range preset', () {
      expect(
        timeAxisInterval(const Duration(hours: 1), 6),
        const Duration(minutes: 10),
      );
      expect(
        timeAxisInterval(const Duration(hours: 24), 6),
        const Duration(hours: 6),
      );
      expect(
        timeAxisInterval(const Duration(days: 7), 6),
        const Duration(days: 2),
      );
      expect(
        timeAxisInterval(const Duration(days: 30), 6),
        const Duration(days: 7),
      );
    });

    test('uses a finer step when more labels fit', () {
      expect(
        timeAxisInterval(const Duration(hours: 24), 12),
        const Duration(hours: 2),
      );
    });

    test('falls back to whole years past the largest step', () {
      expect(
        timeAxisInterval(const Duration(days: 365 * 20), 6),
        const Duration(days: 365 * 4),
      );
    });

    test('treats a non-positive label budget as one label', () {
      expect(
        timeAxisInterval(const Duration(hours: 5), 0),
        const Duration(hours: 6),
      );
    });
  });

  group('timeAxisLabel', () {
    String date(DateTime dt) => 'D${dt.day}';
    String time(DateTime dt) => 'T${dt.hour}:${dt.minute}';

    test('shows the time for sub-day steps', () {
      expect(
        timeAxisLabel(
          DateTime(2026, 11, 15, 6),
          const Duration(hours: 6),
          formatDate: date,
          formatTime: time,
        ),
        'T6:0',
      );
    });

    test('shows the date at local midnight for sub-day steps', () {
      expect(
        timeAxisLabel(
          DateTime(2026, 11, 15),
          const Duration(hours: 6),
          formatDate: date,
          formatTime: time,
        ),
        'D15',
      );
    });

    test('labels day ticks with the nearest midnight', () {
      // A day tick an hour before midnight, as happens across a DST change.
      expect(
        timeAxisLabel(
          DateTime(2026, 10, 28, 23),
          const Duration(days: 7),
          formatDate: date,
          formatTime: time,
        ),
        'D29',
      );
    });

    test('shows the date for steps of a day or more', () {
      expect(
        timeAxisLabel(
          DateTime(2026, 11, 15, 1),
          const Duration(days: 2),
          formatDate: date,
          formatTime: time,
        ),
        'D15',
      );
    });
  });
}
