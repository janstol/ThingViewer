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
  });
}
