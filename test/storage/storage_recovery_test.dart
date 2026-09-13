import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/storage/channel_storage.dart';
import 'package:thingviewer/storage/storage_recovery.dart';

class _Thing {
  final int value;
  const _Thing(this.value);

  factory _Thing.fromJson(Map<String, dynamic> json) =>
      _Thing(json['value'] as int);
}

const _key = 'things';

Future<SharedPreferences> _prefsWith(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('decodeStoredList', () {
    test('is a clean empty outcome when the key is absent', () async {
      final prefs = await _prefsWith({});

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue, isNull);
    });

    test('is a clean empty outcome when the key is empty', () async {
      final prefs = await _prefsWith({_key: ''});

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue, isNull);
    });

    test('parses every entry on a clean list', () async {
      final prefs = await _prefsWith({
        _key: '[{"value": 1}, {"value": 2}]',
      });

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value.map((t) => t.value), [1, 2]);
      expect(outcome.issue, isNull);
    });

    test('quarantines and reports total on unparsable JSON', () async {
      final prefs = await _prefsWith({_key: 'not json'});

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue?.total, isTrue);
      expect(outcome.issue?.skipped, 0);
      expect(quarantinedRaw(prefs, _key), 'not json');
    });

    test('quarantines and reports total when the top level is not a list', () async {
      final prefs = await _prefsWith({_key: '{"value": 1}'});

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue?.total, isTrue);
      expect(quarantinedRaw(prefs, _key), '{"value": 1}');
    });

    test('salvages parsable entries and counts the rest as skipped', () async {
      final raw = '[{"value": 1}, {"bogus": true}, {"value": 3}]';
      final prefs = await _prefsWith({_key: raw});

      final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(outcome.value.map((t) => t.value), [1, 3]);
      expect(outcome.issue?.total, isFalse);
      expect(outcome.issue?.skipped, 1);
      expect(quarantinedRaw(prefs, _key), raw);
    });

    test(
      'keeps a stale quarantine and its issue on a fully clean read',
      () async {
        final prefs = await _prefsWith({
          _key: '[{"value": 1}]',
          quarantineKey(_key): 'old corrupt data',
          quarantineMetaKey(_key): '{"skipped": 2, "total": false}',
        });

        final outcome = decodeStoredList(prefs, _key, _Thing.fromJson);

        expect(outcome.value.map((t) => t.value), [1]);
        expect(quarantinedRaw(prefs, _key), 'old corrupt data');
        expect(outcome.issue?.total, isFalse);
        expect(outcome.issue?.skipped, 2);
      },
    );
  });

  group('decodeStoredMap', () {
    test('is a clean empty outcome when the key is absent', () async {
      final prefs = await _prefsWith({});

      final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue, isNull);
    });

    test('parses every entry on a clean map', () async {
      final prefs = await _prefsWith({
        _key: '{"a": {"value": 1}, "b": {"value": 2}}',
      });

      final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(outcome.value.map((k, v) => MapEntry(k, v.value)), {
        'a': 1,
        'b': 2,
      });
      expect(outcome.issue, isNull);
    });

    test('quarantines and reports total on unparsable JSON', () async {
      final prefs = await _prefsWith({_key: 'not json'});

      final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue?.total, isTrue);
      expect(quarantinedRaw(prefs, _key), 'not json');
    });

    test('quarantines and reports total when the top level is not a map', () async {
      final prefs = await _prefsWith({_key: '[1, 2, 3]'});

      final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(outcome.value, isEmpty);
      expect(outcome.issue?.total, isTrue);
      expect(quarantinedRaw(prefs, _key), '[1, 2, 3]');
    });

    test('salvages parsable entries and counts the rest as skipped', () async {
      final raw = '{"a": {"value": 1}, "b": {"bogus": true}}';
      final prefs = await _prefsWith({_key: raw});

      final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(outcome.value.map((k, v) => MapEntry(k, v.value)), {'a': 1});
      expect(outcome.issue?.total, isFalse);
      expect(outcome.issue?.skipped, 1);
      expect(quarantinedRaw(prefs, _key), raw);
    });

    test(
      'keeps a stale quarantine and its issue on a fully clean read',
      () async {
        final prefs = await _prefsWith({
          _key: '{"a": {"value": 1}}',
          quarantineKey(_key): 'old corrupt data',
          quarantineMetaKey(_key): '{"skipped": 1, "total": false}',
        });

        final outcome = decodeStoredMap(prefs, _key, _Thing.fromJson);

        expect(outcome.value.map((k, v) => MapEntry(k, v.value)), {'a': 1});
        expect(quarantinedRaw(prefs, _key), 'old corrupt data');
        expect(outcome.issue?.total, isFalse);
        expect(outcome.issue?.skipped, 1);
      },
    );
  });

  group('quarantine helpers', () {
    test('clearQuarantine removes the stashed raw value and meta', () async {
      final prefs = await _prefsWith({});
      quarantine(
        prefs,
        _key,
        'corrupt',
        const StorageIssue(key: _key, skipped: 0, total: true),
      );
      expect(quarantinedRaw(prefs, _key), 'corrupt');

      await clearQuarantine(prefs, _key);

      expect(quarantinedRaw(prefs, _key), isNull);
      expect(prefs.getString(quarantineMetaKey(_key)), isNull);
    });

    test('does not overwrite an existing quarantine', () async {
      final prefs = await _prefsWith({});
      quarantine(
        prefs,
        _key,
        'original corrupt data',
        const StorageIssue(key: _key, skipped: 1, total: false),
      );

      quarantine(
        prefs,
        _key,
        'newer corrupt data',
        const StorageIssue(key: _key, skipped: 5, total: false),
      );

      expect(quarantinedRaw(prefs, _key), 'original corrupt data');
    });
  });

  group('full cycle: quarantine survives an ordinary save', () {
    test(
      'a salvaged channel list keeps its quarantine after saveChannels and reload',
      () async {
        const goodChannelJson =
            '{"id": 1, "serverUrl": "https://api.thingspeak.com", '
            '"isPublic": true}';
        final raw = '[$goodChannelJson, {"bogus": true}]';
        final prefs = await _prefsWith({'channels': raw});

        final storage = ChannelStorage(prefs);
        final loaded = storage.load();
        expect(loaded.value, hasLength(1));
        expect(loaded.issue?.skipped, 1);

        // Ordinary save writes back only the salvaged subset.
        await storage.saveChannels(loaded.value);

        // Reload as a fresh instance, as would happen on next launch.
        final reloaded = ChannelStorage(prefs);
        final reloadedOutcome = reloaded.load();

        expect(reloadedOutcome.value, hasLength(1));
        expect(reloaded.corruptRaw, raw);
        expect(reloadedOutcome.issue, isNotNull);
        expect(reloadedOutcome.issue?.skipped, 1);
      },
    );
  });
}
