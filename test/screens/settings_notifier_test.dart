import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/settings_storage.dart';

const _channel = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'My Channel',
);

const _otherChannel = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Other Channel',
);

class _FakeSettingsStorage implements SettingsStorage {
  ThemeMode _themeMode;
  String _dateFormat;
  String _timeFormat;
  int? _startChannelId;
  String? _startChannelServerUrl;
  bool throwOnSave;

  _FakeSettingsStorage({
    ThemeMode themeMode = ThemeMode.system,
    String dateFormat = defaultDateFormat,
    String timeFormat = defaultTimeFormat,
    int? startChannelId,
    String? startChannelServerUrl,
    this.throwOnSave = false,
  })  : _themeMode = themeMode,
        _dateFormat = dateFormat,
        _timeFormat = timeFormat,
        _startChannelId = startChannelId,
        _startChannelServerUrl = startChannelServerUrl;

  @override
  ThemeMode get themeMode => _themeMode;

  @override
  Future<void> saveThemeMode(ThemeMode mode) async {
    if (throwOnSave) throw Exception('storage error');
    _themeMode = mode;
  }

  @override
  String get dateFormat => _dateFormat;

  @override
  Future<void> saveDateFormat(String format) async {
    if (throwOnSave) throw Exception('storage error');
    _dateFormat = format;
  }

  @override
  String get timeFormat => _timeFormat;

  @override
  Future<void> saveTimeFormat(String format) async {
    if (throwOnSave) throw Exception('storage error');
    _timeFormat = format;
  }

  @override
  int? get startChannelId => _startChannelId;

  @override
  String? get startChannelServerUrl => _startChannelServerUrl;

  @override
  Future<void> saveStartChannel(Channel? channel) async {
    if (throwOnSave) throw Exception('storage error');
    _startChannelId = channel?.id;
    _startChannelServerUrl = channel?.serverUrl;
  }
}

void main() {
  group('initial values', () {
    test('reads from storage', () {
      final storage = _FakeSettingsStorage(
        themeMode: ThemeMode.dark,
        dateFormat: 'yyyy-MM-dd',
        timeFormat: 'hh:mm a',
      );
      final notifier = SettingsNotifier(storage);

      expect(notifier.themeMode, ThemeMode.dark);
      expect(notifier.dateFormat, 'yyyy-MM-dd');
      expect(notifier.timeFormat, 'hh:mm a');
      notifier.dispose();
    });
  });

  group('setThemeMode', () {
    test('updates in-memory value and persists', () async {
      final storage = _FakeSettingsStorage();
      final notifier = SettingsNotifier(storage);

      await notifier.setThemeMode(ThemeMode.dark);

      expect(notifier.themeMode, ThemeMode.dark);
      expect(storage.themeMode, ThemeMode.dark);
      notifier.dispose();
    });

    test('reverts to previous value when storage throws', () async {
      final storage = _FakeSettingsStorage(
        themeMode: ThemeMode.light,
        throwOnSave: true,
      );
      final notifier = SettingsNotifier(storage);

      await notifier.setThemeMode(ThemeMode.dark);

      // In-memory value should be reverted to the original.
      expect(notifier.themeMode, ThemeMode.light);
      notifier.dispose();
    });

    test('notifies listeners on successful save', () async {
      final notifier = SettingsNotifier(_FakeSettingsStorage());
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      await notifier.setThemeMode(ThemeMode.dark);

      expect(notifyCount, 1);
      notifier.dispose();
    });

    test('notifies listeners twice on storage failure (update then revert)', () async {
      final notifier = SettingsNotifier(_FakeSettingsStorage(throwOnSave: true));
      int notifyCount = 0;
      notifier.addListener(() => notifyCount++);

      await notifier.setThemeMode(ThemeMode.dark);

      expect(notifyCount, 2); // once optimistically, once for the revert
      notifier.dispose();
    });
  });

  group('setDateFormat', () {
    test('updates and persists', () async {
      final storage = _FakeSettingsStorage();
      final notifier = SettingsNotifier(storage);

      await notifier.setDateFormat('yyyy-MM-dd');

      expect(notifier.dateFormat, 'yyyy-MM-dd');
      expect(storage.dateFormat, 'yyyy-MM-dd');
      notifier.dispose();
    });

    test('reverts when storage throws', () async {
      final storage = _FakeSettingsStorage(throwOnSave: true);
      final notifier = SettingsNotifier(storage);
      final original = notifier.dateFormat;

      await notifier.setDateFormat('yyyy-MM-dd');

      expect(notifier.dateFormat, original);
      notifier.dispose();
    });
  });

  group('setTimeFormat', () {
    test('updates and persists', () async {
      final storage = _FakeSettingsStorage();
      final notifier = SettingsNotifier(storage);

      await notifier.setTimeFormat('hh:mm a');

      expect(notifier.timeFormat, 'hh:mm a');
      expect(storage.timeFormat, 'hh:mm a');
      notifier.dispose();
    });

    test('reverts when storage throws', () async {
      final storage = _FakeSettingsStorage(throwOnSave: true);
      final notifier = SettingsNotifier(storage);
      final original = notifier.timeFormat;

      await notifier.setTimeFormat('hh:mm a');

      expect(notifier.timeFormat, original);
      notifier.dispose();
    });
  });

  group('setStartChannel', () {
    test('updates and persists', () async {
      final storage = _FakeSettingsStorage();
      final notifier = SettingsNotifier(storage);

      await notifier.setStartChannel(_channel);

      expect(storage.startChannelId, _channel.id);
      expect(storage.startChannelServerUrl, _channel.serverUrl);
      notifier.dispose();
    });

    test('is re-read by a fresh notifier', () async {
      final storage = _FakeSettingsStorage();
      final notifier = SettingsNotifier(storage);
      await notifier.setStartChannel(_channel);
      notifier.dispose();

      final fresh = SettingsNotifier(storage);

      expect(fresh.startChannel([_channel]), _channel);
      fresh.dispose();
    });

    test('clears persisted keys when set to null', () async {
      final storage = _FakeSettingsStorage(
        startChannelId: _channel.id,
        startChannelServerUrl: _channel.serverUrl,
      );
      final notifier = SettingsNotifier(storage);

      await notifier.setStartChannel(null);

      expect(storage.startChannelId, isNull);
      expect(storage.startChannelServerUrl, isNull);
      notifier.dispose();
    });

    test('reverts when storage throws', () async {
      final storage = _FakeSettingsStorage(throwOnSave: true);
      final notifier = SettingsNotifier(storage);

      await notifier.setStartChannel(_channel);

      expect(notifier.startChannel([_channel]), isNull);
      notifier.dispose();
    });
  });

  group('startChannel', () {
    test('returns null when unset', () {
      final notifier = SettingsNotifier(_FakeSettingsStorage());

      expect(notifier.startChannel([_channel, _otherChannel]), isNull);
      notifier.dispose();
    });

    test('returns the matching channel', () async {
      final notifier = SettingsNotifier(_FakeSettingsStorage());
      await notifier.setStartChannel(_channel);

      expect(
        notifier.startChannel([_channel, _otherChannel]),
        _channel,
      );
      notifier.dispose();
    });

    test('returns null when the stored channel is no longer in the list', () async {
      final notifier = SettingsNotifier(_FakeSettingsStorage());
      await notifier.setStartChannel(_channel);

      expect(notifier.startChannel([_otherChannel]), isNull);
      notifier.dispose();
    });
  });
}
