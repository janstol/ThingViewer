import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/migration/migration_service.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/settings_storage.dart';

// LegacyChannel and LegacyChannelAdapter are @visibleForTesting — imported
// directly so tests can seed Hive boxes with legacy-format data.

late Directory _tempDir;

// ── Helpers ───────────────────────────────────────────────────────────────────

/// In-memory SharedPreferences instance pre-seeded with [seed].
Future<SharedPreferences> _freshPrefs([Map<String, Object> seed = const {}]) {
  SharedPreferences.setMockInitialValues(Map.of(seed));
  return SharedPreferences.getInstance();
}

/// Creates a [MigrationService] with Hive initialisation already done.
/// Passes a no-op [hiveInit] so tests don't need the `path_provider` plugin.
MigrationService _service(SharedPreferences prefs) =>
    MigrationService(prefs, hiveInit: () async {});

/// Seeds the legacy typed channels box.
Future<void> _seedChannels(List<LegacyChannel> channels) async {
  final box = await Hive.openBox<LegacyChannel>('channels');
  await box.clear();
  for (final c in channels) {
    await box.put(c.id, c);
  }
  await box.close();
}

/// Seeds the legacy dynamic settings box.
Future<void> _seedSettings({
  String? dateFormat,
  String? timeFormat,
  int? themeMode,
}) async {
  final box = await Hive.openBox<dynamic>('settings');
  await box.clear();
  if (dateFormat != null) await box.put('dateFormat', dateFormat);
  if (timeFormat != null) await box.put('timeFormat', timeFormat);
  if (themeMode != null) await box.put('themeMode', themeMode);
  await box.close();
}

/// Deletes both legacy Hive boxes between tests for isolation.
Future<void> _resetBoxes() async {
  await Hive.deleteBoxFromDisk('channels');
  await Hive.deleteBoxFromDisk('settings');
}

// ── Test suite ────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
    _tempDir = await Directory.systemTemp.createTemp('migration_test_');
    Hive.init(_tempDir.path);
    Hive.registerAdapter(LegacyChannelAdapter());
  });

  tearDownAll(() async {
    await Hive.close();
    await _tempDir.delete(recursive: true);
  });

  setUp(_resetBoxes);

  // ── Flag behaviour ──────────────────────────────────────────────────────────

  group('flag behaviour', () {
    test('sets migration_v2_done on successful run', () async {
      final prefs = await _freshPrefs();
      await _service(prefs).run();
      expect(prefs.getBool('migration_v2_done'), isTrue);
    });

    test('is a no-op when flag is already set', () async {
      final prefs = await _freshPrefs({'migration_v2_done': true});
      await _seedSettings(dateFormat: 'd.M.y');

      await _service(prefs).run();

      // No settings migrated — flag short-circuited before Hive was read.
      expect(prefs.containsKey('dateFormat'), isFalse);
    });

    test('sets flag even when Hive box is corrupt', () async {
      // Write garbage bytes so Hive cannot parse the channels box.
      final boxFile = File('${_tempDir.path}/channels.hive');
      await boxFile.writeAsBytes([0xFF, 0xFE, 0x00, 0x01]);

      final prefs = await _freshPrefs();
      await expectLater(_service(prefs).run(), completes);
      expect(prefs.getBool('migration_v2_done'), isTrue);
    });

    test('is idempotent — second run does not change prefs', () async {
      await _seedSettings(
          dateFormat: 'd.M.y', timeFormat: 'HH:mm', themeMode: 1);
      final prefs = await _freshPrefs();

      await _service(prefs).run();
      final snapshot = {for (final k in prefs.getKeys()) k: prefs.get(k)};

      // Second run — flag is now set, must be a no-op.
      await _service(prefs).run();
      final after = {for (final k in prefs.getKeys()) k: prefs.get(k)};
      expect(after, snapshot);
    });
  });

  // ── Channel migration ───────────────────────────────────────────────────────

  group('channel migration', () {
    test('migrates channels sorted by legacy order field', () async {
      await _seedChannels([
        const LegacyChannel(id: 1, order: 2),
        const LegacyChannel(id: 2, order: 0),
        const LegacyChannel(id: 3, order: 1),
      ]);
      final prefs = await _freshPrefs();
      await _service(prefs).run();

      final ids = ChannelStorage(prefs).loadChannels().map((c) => c.id);
      expect(ids, [2, 3, 1]);
    });

    test('normalises empty serverUrl to default ThingSpeak URL', () async {
      await _seedChannels([const LegacyChannel(id: 1, serverUrl: '', order: 0)]);
      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(
        ChannelStorage(prefs).loadChannels().first.serverUrl,
        'https://api.thingspeak.com',
      );
    });

    test('preserves non-empty serverUrl', () async {
      await _seedChannels([
        const LegacyChannel(
            id: 1, serverUrl: 'https://custom.example.com', order: 0),
      ]);
      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(
        ChannelStorage(prefs).loadChannels().first.serverUrl,
        'https://custom.example.com',
      );
    });

    test('converts empty apiKey to null', () async {
      await _seedChannels([const LegacyChannel(id: 1, apiKey: '', order: 0)]);
      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(ChannelStorage(prefs).loadChannels().first.apiKey, isNull);
    });

    test('preserves non-empty apiKey', () async {
      await _seedChannels(
          [const LegacyChannel(id: 1, apiKey: 'ABCDEF12', order: 0)]);
      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(ChannelStorage(prefs).loadChannels().first.apiKey, 'ABCDEF12');
    });

    test('empty channels box produces no channels write', () async {
      final box = await Hive.openBox<LegacyChannel>('channels');
      await box.close();

      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(prefs.containsKey('channels'), isFalse);
    });

    test('does not overwrite channels already in new prefs', () async {
      const existing = Channel(
        id: 99,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: true,
      );
      await _seedChannels([const LegacyChannel(id: 1, order: 0)]);
      final prefs =
          await _freshPrefs({'channels': Channel.listToJson([existing])});

      await _service(prefs).run();

      expect(ChannelStorage(prefs).loadChannels(), [existing]);
    });
  });

  // ── Settings migration — date formats ───────────────────────────────────────

  group('settings migration — date formats', () {
    const cases = {
      'yyyy-MM-dd': 'yyyy-MM-dd',
      'MM/dd/yyyy': 'MM/dd/yyyy',
      'MM/dd/yy': 'MM/dd/yyyy',
      'dd/MM/yyyy': 'dd.MM.yyyy',
      'dd/MM/yy': 'dd.MM.yyyy',
      'd.M.y': 'dd.MM.yyyy',
      'dd.MM.y': 'dd.MM.yyyy',
    };

    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () async {
        await _seedSettings(dateFormat: entry.key);
        final prefs = await _freshPrefs();
        await _service(prefs).run();
        expect(prefs.getString('dateFormat'), entry.value);
      });
    }

    test('unknown format falls back to default', () async {
      await _seedSettings(dateFormat: 'nonsense');
      final prefs = await _freshPrefs();
      await _service(prefs).run();
      expect(prefs.getString('dateFormat'), defaultDateFormat);
    });

    test('does not overwrite dateFormat already in new prefs', () async {
      await _seedSettings(dateFormat: 'MM/dd/yy');
      final prefs = await _freshPrefs({'dateFormat': 'yyyy-MM-dd'});
      await _service(prefs).run();
      expect(prefs.getString('dateFormat'), 'yyyy-MM-dd');
    });
  });

  // ── Settings migration — time formats ───────────────────────────────────────

  group('settings migration — time formats', () {
    const cases = {
      'HH:mm:ss': 'HH:mm',
      'HH:mm': 'HH:mm',
      'h:mm:ss a': 'hh:mm a',
      'h:mm a': 'hh:mm a',
      'hh:mm:ss a': 'hh:mm a',
      'hh:mm a': 'hh:mm a',
    };

    for (final entry in cases.entries) {
      test('${entry.key} → ${entry.value}', () async {
        await _seedSettings(timeFormat: entry.key);
        final prefs = await _freshPrefs();
        await _service(prefs).run();
        expect(prefs.getString('timeFormat'), entry.value);
      });
    }

    test('unknown format falls back to default', () async {
      await _seedSettings(timeFormat: 'gobbledygook');
      final prefs = await _freshPrefs();
      await _service(prefs).run();
      expect(prefs.getString('timeFormat'), defaultTimeFormat);
    });

    test('does not overwrite timeFormat already in new prefs', () async {
      await _seedSettings(timeFormat: 'h:mm a');
      final prefs = await _freshPrefs({'timeFormat': 'HH:mm'});
      await _service(prefs).run();
      expect(prefs.getString('timeFormat'), 'HH:mm');
    });
  });

  // ── Settings migration — themeMode ──────────────────────────────────────────

  group('settings migration — themeMode', () {
    test('passes valid index through unchanged', () async {
      await _seedSettings(themeMode: 2); // ThemeMode.dark
      final prefs = await _freshPrefs();
      await _service(prefs).run();
      expect(prefs.getInt('themeMode'), 2);
    });

    test('clamps out-of-range index to max valid value (2)', () async {
      await _seedSettings(themeMode: 99);
      final prefs = await _freshPrefs();
      await _service(prefs).run();
      expect(prefs.getInt('themeMode'), 2);
    });

    test('does not overwrite themeMode already in new prefs', () async {
      await _seedSettings(themeMode: 2); // dark
      final prefs = await _freshPrefs({'themeMode': 0}); // system already set
      await _service(prefs).run();
      expect(prefs.getInt('themeMode'), 0);
    });

    test('empty settings box produces no settings write', () async {
      final box = await Hive.openBox<dynamic>('settings');
      await box.close();

      final prefs = await _freshPrefs();
      await _service(prefs).run();

      expect(prefs.containsKey('dateFormat'), isFalse);
      expect(prefs.containsKey('timeFormat'), isFalse);
      expect(prefs.containsKey('themeMode'), isFalse);
    });
  });
}
