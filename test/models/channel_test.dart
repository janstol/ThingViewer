import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/channel.dart';

void main() {
  group('authError', () {
    test('defaults to false', () {
      const channel = Channel(
        id: 1,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: true,
      );

      expect(channel.authError, isFalse);
    });

    test('round-trips through toJson/fromJson when true', () {
      const channel = Channel(
        id: 1,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: true,
        authError: true,
      );

      final decoded = Channel.fromJson(channel.toJson());

      expect(decoded.authError, isTrue);
    });

    test('is omitted from toJson when false', () {
      const channel = Channel(
        id: 1,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: true,
      );

      expect(channel.toJson().containsKey('authError'), isFalse);
    });

    test('an old stored payload without the key decodes to false', () {
      final decoded = Channel.fromJson({
        'id': 1,
        'serverUrl': 'https://api.thingspeak.com',
        'isPublic': true,
      });

      expect(decoded.authError, isFalse);
    });

    test('copyWith preserves authError unless overridden', () {
      const channel = Channel(
        id: 1,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: true,
        authError: true,
      );

      expect(channel.copyWith(name: 'Renamed').authError, isTrue);
      expect(channel.copyWith(authError: false).authError, isFalse);
    });
  });
}
