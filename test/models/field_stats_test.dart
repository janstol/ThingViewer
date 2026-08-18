import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/field_stats.dart';

final _now = DateTime(2026, 1, 1);

FieldValue _v(double value, {int minutesAgo = 0}) => FieldValue(
  createdAt: _now.subtract(Duration(minutes: minutesAgo)),
  value: value,
);

void main() {
  test('empty list returns null', () {
    expect(computeFieldStats([]), isNull);
  });

  test('single value: count 1, sum/min/max/average all that value', () {
    final stats = computeFieldStats([_v(5)]);
    expect(stats, isNotNull);
    expect(stats!.count, 1);
    expect(stats.sum, 5);
    expect(stats.min, 5);
    expect(stats.max, 5);
    expect(stats.average, 5);
  });

  test('known multi-value fixture', () {
    final stats = computeFieldStats([
      _v(1, minutesAgo: 3),
      _v(4, minutesAgo: 2),
      _v(2, minutesAgo: 1),
    ]);
    expect(stats, isNotNull);
    expect(stats!.count, 3);
    expect(stats.sum, 7);
    expect(stats.min, 1);
    expect(stats.max, 4);
    expect(stats.average, closeTo(7 / 3, 1e-9));
  });

  test('negative values', () {
    final stats = computeFieldStats([_v(-3), _v(2), _v(-5)]);
    expect(stats, isNotNull);
    expect(stats!.sum, -6);
    expect(stats.min, -5);
    expect(stats.max, 2);
    expect(stats.average, -2);
  });

  test('delta series sums to last minus first', () {
    final raw = [
      _v(10, minutesAgo: 2),
      _v(13, minutesAgo: 1),
      _v(17, minutesAgo: 0),
    ];
    final stats = computeFieldStats(deltaValues(raw));
    expect(stats, isNotNull);
    expect(stats!.sum, closeTo(raw.last.value - raw.first.value, 1e-9));
  });

  test('a series summing to exactly zero returns an instance, not null', () {
    final stats = computeFieldStats([_v(5), _v(-5)]);
    expect(stats, isNotNull);
    expect(stats!.sum, 0);
    expect(stats.count, 2);
  });
}
