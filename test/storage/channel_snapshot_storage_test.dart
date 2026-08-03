import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/channel_snapshot.dart';
import 'package:thingviewer/storage/channel_snapshot_storage.dart';

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

  test('snapshotFor is null when nothing is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final storage = ChannelSnapshotStorage(
      await SharedPreferences.getInstance(),
    );

    expect(storage.snapshotFor(_channel), isNull);
  });

  group('save', () {
    test('stores the first snapshot for a channel as-is', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      final snapshot = ChannelSnapshot(
        description: 'A channel',
        fields: [FieldSnapshot(id: 1, label: 'Temp', value: 21.5)],
        fetchedAt: DateTime.utc(2024, 1, 1),
      );

      await storage.save(_channel, snapshot);

      final saved = storage.snapshotFor(_channel);
      expect(saved?.description, 'A channel');
      expect(saved?.fields.single.value, 21.5);
    });

    test('merges a subsequent save over the existing snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        _channel,
        ChannelSnapshot(
          fields: [
            FieldSnapshot(id: 1, label: 'Temp', value: 20),
            FieldSnapshot(id: 2, label: 'Humidity', value: 50),
          ],
          fetchedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      await storage.save(
        _channel,
        ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, label: 'Temp', value: 21)],
          fetchedAt: DateTime.utc(2024, 1, 2),
        ),
      );

      final saved = storage.snapshotFor(_channel);
      final field1 = saved?.fields.firstWhere((f) => f.id == 1);
      final field2 = saved?.fields.firstWhere((f) => f.id == 2);
      expect(field1?.value, 21);
      expect(field2?.value, 50);
    });

    test('is isolated per channel', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.save(
        _channel,
        ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 1)),
      );

      expect(storage.snapshotFor(_otherChannel), isNull);
    });

    test('persists across storage instances', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final first = ChannelSnapshotStorage(prefs);
      await first.save(
        _channel,
        ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, value: 21.5)],
          fetchedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      final second = ChannelSnapshotStorage(prefs);

      expect(second.snapshotFor(_channel)?.fields.single.value, 21.5);
    });
  });

  group('remove', () {
    test('deletes a stored snapshot', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        _channel,
        ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 1)),
      );

      await storage.remove(_channel);

      expect(storage.snapshotFor(_channel), isNull);
    });

    test('is a no-op when nothing is stored for the channel', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.remove(_channel);

      expect(storage.snapshotFor(_channel), isNull);
    });
  });

  group('migrateChannel', () {
    test('re-keys the snapshot onto the new channel identity', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        _channel,
        ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, value: 21.5)],
          fetchedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );
      await storage.migrateChannel(_channel, migrated);

      expect(storage.snapshotFor(_channel), isNull);
      expect(storage.snapshotFor(migrated)?.fields.single.value, 21.5);

      final reloaded = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      expect(reloaded.snapshotFor(migrated)?.fields.single.value, 21.5);
    });

    test('leaves other channels untouched', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      await storage.save(
        _channel,
        ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 1)),
      );
      await storage.save(
        _otherChannel,
        ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, value: 50)],
          fetchedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );
      await storage.migrateChannel(_channel, migrated);

      expect(storage.snapshotFor(_otherChannel)?.fields.single.value, 50);
    });

    test('is a no-op when nothing is stored for the channel', () async {
      SharedPreferences.setMockInitialValues({});
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );
      const migrated = Channel(
        id: 42,
        serverUrl: 'https://example.com',
        isPublic: true,
      );

      await storage.migrateChannel(_channel, migrated);

      expect(storage.snapshotFor(migrated), isNull);
    });
  });

  group('a corrupt blob', () {
    test('yields no snapshots instead of throwing', () async {
      SharedPreferences.setMockInitialValues({
        'channelSnapshots': 'not json',
      });
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );

      expect(storage.snapshotFor(_channel), isNull);
      expect(storage.issue?.total, isTrue);
    });

    test('is preserved via corruptRaw and survives a later write', () async {
      SharedPreferences.setMockInitialValues({
        'channelSnapshots': 'not json',
      });
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.save(
        _channel,
        ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 1)),
      );

      expect(storage.corruptRaw, 'not json');
      expect(storage.snapshotFor(_channel), isNotNull);
    });

    test('discardCorrupt clears the quarantine and the issue', () async {
      SharedPreferences.setMockInitialValues({
        'channelSnapshots': 'not json',
      });
      final storage = ChannelSnapshotStorage(
        await SharedPreferences.getInstance(),
      );

      await storage.discardCorrupt();

      expect(storage.corruptRaw, isNull);
      expect(storage.issue, isNull);
      expect(storage.snapshotFor(_channel), isNull);
    });
  });

  group('reload', () {
    test('picks up changes written directly to prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = ChannelSnapshotStorage(prefs);
      expect(storage.snapshotFor(_channel), isNull);

      final other = ChannelSnapshotStorage(prefs);
      await other.save(
        _channel,
        ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, value: 21.5)],
          fetchedAt: DateTime.utc(2024, 1, 1),
        ),
      );

      storage.reload();

      expect(storage.snapshotFor(_channel)?.fields.single.value, 21.5);
    });
  });
}
