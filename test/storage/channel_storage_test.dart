import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/storage/channel_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadChannels returns an empty list when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    expect(storage.loadChannels(), isEmpty);
    expect(storage.issue, isNull);
  });

  test('saveChannels persists channels retrievable by loadChannels', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChannelStorage(await SharedPreferences.getInstance());

    await storage.saveChannels([_channel]);

    expect(storage.loadChannels(), [_channel]);
  });

  group('a corrupt blob', () {
    test('yields an empty list and reports a total issue', () async {
      SharedPreferences.setMockInitialValues({'channels': 'not json'});
      final storage = ChannelStorage(await SharedPreferences.getInstance());

      final outcome = storage.load();

      expect(outcome.value, isEmpty);
      expect(outcome.issue?.total, isTrue);
      expect(storage.issue?.total, isTrue);
    });

    test('is preserved via corruptRaw', () async {
      SharedPreferences.setMockInitialValues({'channels': 'not json'});
      final storage = ChannelStorage(await SharedPreferences.getInstance());
      storage.load();

      expect(storage.corruptRaw, 'not json');
    });

    test('survives a later saveChannels call', () async {
      SharedPreferences.setMockInitialValues({'channels': 'not json'});
      final storage = ChannelStorage(await SharedPreferences.getInstance());
      storage.load();

      await storage.saveChannels([_channel]);

      expect(storage.corruptRaw, 'not json');
      expect(storage.loadChannels(), [_channel]);
    });

    test('discardCorrupt clears the quarantine and the issue', () async {
      SharedPreferences.setMockInitialValues({'channels': 'not json'});
      final storage = ChannelStorage(await SharedPreferences.getInstance());
      storage.load();

      await storage.discardCorrupt();

      expect(storage.corruptRaw, isNull);
      expect(storage.issue, isNull);
      expect(storage.loadChannels(), isEmpty);
    });
  });
}
