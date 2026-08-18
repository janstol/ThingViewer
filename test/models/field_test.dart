import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/field.dart';

void main() {
  group('formatFieldValue', () {
    test('whole numbers pad to minimum decimals', () {
      expect(formatFieldValue(21.0), '21.00');
      expect(formatFieldValue(-21.0), '-21.00');
    });

    test('one decimal pads to minimum decimals', () {
      expect(formatFieldValue(21.5), '21.50');
    });

    test('value exactly at the cap is shown in full', () {
      expect(formatFieldValue(12.3456), '12.3456');
    });

    test('value beyond the cap is rounded to it', () {
      expect(formatFieldValue(49.2871934), '49.287193');
    });

    test('small magnitude below minimum decimals is shown in full', () {
      expect(formatFieldValue(0.000125), '0.000125');
    });

    test('zero pads to minimum decimals', () {
      expect(formatFieldValue(0.0), '0.00');
    });

    test('magnitudes below 1e-6 collapse to zero (accepted limitation)', () {
      expect(formatFieldValue(0.0000001), '0.00');
    });

    test('fixed decimals of 0 rounds to a whole number', () {
      expect(formatFieldValue(12.3456, decimals: 0), '12');
      expect(formatFieldValue(12.5, decimals: 0), '13');
    });

    test('fixed decimals of 6 pads short values and rounds long ones', () {
      expect(formatFieldValue(21.0, decimals: 6), '21.000000');
      expect(formatFieldValue(49.2871934, decimals: 6), '49.287193');
    });
  });

  group('autoDecimalsFor', () {
    test('a whole number needs the minimum 2 decimals', () {
      expect(autoDecimalsFor(21.0), 2);
    });

    test('a value with one real decimal still needs the minimum 2', () {
      expect(autoDecimalsFor(21.5), 2);
    });

    test('a value needing more than the minimum reports its real count', () {
      expect(autoDecimalsFor(12.3456), 4);
    });

    test('a value beyond the cap reports the capped count', () {
      expect(autoDecimalsFor(49.2871934), 6);
    });
  });

  group('deltaValues', () {
    test('empty input returns empty output', () {
      expect(deltaValues([]), isEmpty);
    });

    test('a single value returns empty output', () {
      expect(
        deltaValues([FieldValue(createdAt: DateTime(2024), value: 5)]),
        isEmpty,
      );
    });

    test(
      'increasing series yields positive deltas keyed by the later timestamp',
      () {
        final t1 = DateTime(2024, 1, 1);
        final t2 = DateTime(2024, 1, 2);
        final t3 = DateTime(2024, 1, 3);
        final result = deltaValues([
          FieldValue(createdAt: t1, value: 10),
          FieldValue(createdAt: t2, value: 15),
          FieldValue(createdAt: t3, value: 25),
        ]);

        expect(result, hasLength(2));
        expect(result[0].createdAt, t2);
        expect(result[0].value, 5);
        expect(result[1].createdAt, t3);
        expect(result[1].value, 10);
      },
    );

    test('decreasing series yields negative deltas', () {
      final t1 = DateTime(2024, 1, 1);
      final t2 = DateTime(2024, 1, 2);
      final result = deltaValues([
        FieldValue(createdAt: t1, value: 20),
        FieldValue(createdAt: t2, value: 12),
      ]);

      expect(result, hasLength(1));
      expect(result[0].value, -8);
    });
  });

  group('bucketAverage', () {
    List<FieldValue> series(int length) => [
      for (var i = 0; i < length; i++)
        FieldValue(createdAt: DateTime(2024, 1, 1 + i), value: i.toDouble()),
    ];

    test('returns input unchanged when already within the limit', () {
      final values = series(5);
      expect(bucketAverage(values, 10), same(values));
      expect(bucketAverage(values, 5), same(values));
    });

    test('empty input returns empty output', () {
      expect(bucketAverage([], 10), isEmpty);
    });

    test('averages values within a bucket', () {
      final values = series(4);
      final result = bucketAverage(values, 2);

      expect(result, hasLength(2));
      expect(result[0].value, 0.5); // mean of 0, 1
      expect(result[1].value, 2.5); // mean of 2, 3
    });

    test('timestamp is the midpoint of the bucket', () {
      final values = series(4);
      final result = bucketAverage(values, 2);

      expect(result[0].createdAt, DateTime(2024, 1, 1, 12));
      expect(result[1].createdAt, DateTime(2024, 1, 3, 12));
    });

    test('maxPoints of 1 collapses to a single point', () {
      final values = series(4);
      final result = bucketAverage(values, 1);

      expect(result, hasLength(1));
      expect(result[0].value, 1.5); // mean of 0..3
    });

    test(
      'a length not evenly divisible by maxPoints still covers all input',
      () {
        final values = series(7);
        final result = bucketAverage(values, 3);

        expect(result, hasLength(3));
        // buckets: [0,1], [2,3], [4,5,6]
        expect(result[0].value, 0.5);
        expect(result[1].value, 2.5);
        expect(result[2].value, 5.0);
      },
    );
  });
}
