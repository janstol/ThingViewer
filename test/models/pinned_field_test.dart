import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/pinned_field.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  test('matches compares against a channel by serverUrl and id', () {
    const pin = PinnedField(
      serverUrl: 'https://api.thingspeak.com',
      channelId: 1,
      fieldId: 2,
    );

    expect(pin.matches(_channel), isTrue);
    expect(
      pin.matches(
        const Channel(
          id: 2,
          serverUrl: 'https://api.thingspeak.com',
          isPublic: true,
        ),
      ),
      isFalse,
    );
  });

  group('equality', () {
    test('is identity-only, ignoring snapshot fields', () {
      const a = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
        value: 1,
      );
      const b = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
        value: 99,
        label: 'different label',
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('differs when identity fields differ', () {
      const a = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
      );
      const b = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 3,
      );

      expect(a == b, isFalse);
    });
  });

  group('copyWith', () {
    test('overrides only the given fields', () {
      const pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
        label: 'Temperature',
        value: 20,
      );

      final updated = pin.copyWith(value: 21);

      expect(updated.label, 'Temperature');
      expect(updated.value, 21);
    });

    test('does not clear existing snapshot fields when passed null', () {
      final valueAt = DateTime(2024, 1, 1);
      final pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
        value: 20,
        valueAt: valueAt,
      );

      final updated = pin.copyWith();

      expect(updated.value, 20);
      expect(updated.valueAt, valueAt);
    });
  });

  group('JSON round trip', () {
    test('round trips a fully populated snapshot', () {
      final pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
        label: 'Temperature',
        value: 21.5,
        valueAt: DateTime.utc(2024, 3, 1, 12),
        fetchedAt: DateTime.utc(2024, 3, 1, 12, 5),
      );

      final decoded = PinnedField.fromJson(pin.toJson());

      expect(decoded, pin);
      expect(decoded.label, pin.label);
      expect(decoded.value, pin.value);
      expect(decoded.valueAt, pin.valueAt);
      expect(decoded.fetchedAt, pin.fetchedAt);
    });

    test('round trips with null snapshot fields', () {
      const pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
      );

      final decoded = PinnedField.fromJson(pin.toJson());

      expect(decoded, pin);
      expect(decoded.label, isNull);
      expect(decoded.value, isNull);
      expect(decoded.valueAt, isNull);
      expect(decoded.fetchedAt, isNull);
    });

    test('parses an integer value as a double', () {
      final json = {
        'serverUrl': 'https://api.thingspeak.com',
        'channelId': 1,
        'fieldId': 2,
        'value': 5,
      };

      final decoded = PinnedField.fromJson(json);

      expect(decoded.value, 5.0);
    });
  });
}
