import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

    test('clears a stale quarantine on a fully clean read', () async {
      final prefs = await _prefsWith({
        _key: '[{"value": 1}]',
        quarantineKey(_key): 'old corrupt data',
      });

      decodeStoredList(prefs, _key, _Thing.fromJson);

      expect(quarantinedRaw(prefs, _key), isNull);
    });
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

    test('clears a stale quarantine on a fully clean read', () async {
      final prefs = await _prefsWith({
        _key: '{"a": {"value": 1}}',
        quarantineKey(_key): 'old corrupt data',
      });

      decodeStoredMap(prefs, _key, _Thing.fromJson);

      expect(quarantinedRaw(prefs, _key), isNull);
    });
  });

  group('quarantine helpers', () {
    test('clearQuarantine removes the stashed raw value', () async {
      final prefs = await _prefsWith({});
      quarantine(prefs, _key, 'corrupt');
      expect(quarantinedRaw(prefs, _key), 'corrupt');

      await clearQuarantine(prefs, _key);

      expect(quarantinedRaw(prefs, _key), isNull);
    });
  });
}
