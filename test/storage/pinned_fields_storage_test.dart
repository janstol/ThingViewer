import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('isPinned is false when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = PinnedFieldsStorage(await SharedPreferences.getInstance());

    expect(storage.isPinned(_channel, 1), isFalse);
  });

  group('toggle', () {
    test('pins a field that was not pinned', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.toggle(_channel, 1);

      expect(storage.isPinned(_channel, 1), isTrue);
    });

    test('unpins a field that was pinned', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);

      await storage.toggle(_channel, 1);

      expect(storage.isPinned(_channel, 1), isFalse);
    });

    test('is isolated per channel and field id', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.toggle(_channel, 1);
      await storage.toggle(_otherChannel, 1);

      expect(storage.isPinned(_channel, 1), isTrue);
      expect(storage.isPinned(_channel, 2), isFalse);
      expect(storage.isPinned(_otherChannel, 1), isTrue);
    });

    test('persists across storage instances', () async {
      SharedPreferences.setMockInitialValues({});
      final first = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await first.toggle(_channel, 1);

      final second = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      expect(second.isPinned(_channel, 1), isTrue);
    });
  });

  group('pins', () {
    test('filters out orphaned pins not matching the given channels', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);
      await storage.toggle(_otherChannel, 1);

      expect(storage.pins([_channel]), hasLength(1));
      expect(storage.pins([_channel]).single.channelId, _channel.id);
      expect(storage.pins([_channel, _otherChannel]), hasLength(2));
      expect(storage.pins([]), isEmpty);
    });
  });

  group('migrateChannel', () {
    test('re-keys pins onto the new channel identity', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);
      await storage.toggle(_channel, 2);

      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );
      await storage.migrateChannel(_channel, migrated);

      expect(storage.isPinned(_channel, 1), isFalse);
      expect(storage.isPinned(migrated, 1), isTrue);
      expect(storage.isPinned(migrated, 2), isTrue);

      final reloaded = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      expect(reloaded.isPinned(migrated, 1), isTrue);
      expect(reloaded.isPinned(migrated, 2), isTrue);
    });

    test('leaves other channels untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);
      await storage.toggle(_otherChannel, 1);

      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );
      await storage.migrateChannel(_channel, migrated);

      expect(storage.isPinned(_otherChannel, 1), isTrue);
    });

    test('is a no-op when nothing is pinned for the channel', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );

      await storage.migrateChannel(_channel, migrated);

      expect(storage.isPinned(migrated, 1), isFalse);
    });
  });

  group('a corrupt blob', () {
    test('yields no pins instead of throwing', () async {
      SharedPreferences.setMockInitialValues({'pinnedFields': 'not json'});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      expect(storage.pins([_channel]), isEmpty);
      expect(storage.issue?.total, isTrue);
    });

    test('is preserved via corruptRaw and survives a later write', () async {
      SharedPreferences.setMockInitialValues({'pinnedFields': 'not json'});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.toggle(_channel, 1);

      expect(storage.corruptRaw, 'not json');
      expect(storage.isPinned(_channel, 1), isTrue);
    });

    test('discardCorrupt clears the quarantine and the issue', () async {
      SharedPreferences.setMockInitialValues({'pinnedFields': 'not json'});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.discardCorrupt();

      expect(storage.corruptRaw, isNull);
      expect(storage.issue, isNull);
      expect(storage.isPinned(_channel, 1), isFalse);
    });
  });

  group('exportJson / importJson', () {
    test('round trips pins across storage instances', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);
      await storage.toggle(_otherChannel, 2);

      final exported = storage.exportJson();

      SharedPreferences.setMockInitialValues({});
      final target = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await target.importJson(exported);

      expect(target.isPinned(_channel, 1), isTrue);
      expect(target.isPinned(_otherChannel, 2), isTrue);
    });

    test('importJson replaces any existing pins', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.toggle(_channel, 1);

      await storage.importJson([
        PinnedField(
          serverUrl: _otherChannel.serverUrl,
          channelId: _otherChannel.id,
          fieldId: 3,
        ).toJson(),
      ]);

      expect(storage.isPinned(_channel, 1), isFalse);
      expect(storage.isPinned(_otherChannel, 3), isTrue);
    });

    test('importJson skips entries that are not maps', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = PinnedFieldsStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.importJson(['not a map']);

      expect(storage.pins([_channel, _otherChannel]), isEmpty);
    });
  });

  group('reload', () {
    test('picks up changes written directly to prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = PinnedFieldsStorage(prefs);
      expect(storage.isPinned(_channel, 1), isFalse);

      final other = PinnedFieldsStorage(prefs);
      await other.toggle(_channel, 1);

      storage.reload();

      expect(storage.isPinned(_channel, 1), isTrue);
    });
  });
}
