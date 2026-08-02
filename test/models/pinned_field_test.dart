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
    test('is equal when identity fields match', () {
      const a = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
      );
      const b = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
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
      );

      final updated = pin.copyWith(fieldId: 3);

      expect(updated.serverUrl, pin.serverUrl);
      expect(updated.channelId, pin.channelId);
      expect(updated.fieldId, 3);
    });

    test('keeps existing fields when passed nothing', () {
      const pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
      );

      final updated = pin.copyWith();

      expect(updated, pin);
    });
  });

  group('JSON round trip', () {
    test('round trips identity fields', () {
      const pin = PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 2,
      );

      final decoded = PinnedField.fromJson(pin.toJson());

      expect(decoded, pin);
    });

    test('ignores unknown legacy snapshot keys', () {
      final json = {
        'serverUrl': 'https://api.thingspeak.com',
        'channelId': 1,
        'fieldId': 2,
        'label': 'Temperature',
        'value': 21.5,
        'valueAt': '2024-03-01T12:00:00.000Z',
        'fetchedAt': '2024-03-01T12:05:00.000Z',
      };

      final decoded = PinnedField.fromJson(json);

      expect(
        decoded,
        const PinnedField(
          serverUrl: 'https://api.thingspeak.com',
          channelId: 1,
          fieldId: 2,
        ),
      );
    });
  });
}
