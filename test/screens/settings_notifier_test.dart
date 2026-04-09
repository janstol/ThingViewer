import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/screens/settings/settings_notifier.dart';
import 'package:thingviewer/storage/settings_storage.dart';

class _FakeSettingsStorage implements SettingsStorage {
  ThemeMode _themeMode;
  String _dateFormat;
  String _timeFormat;
  bool throwOnSave;

  _FakeSettingsStorage({
    ThemeMode themeMode = ThemeMode.system,
    String dateFormat = defaultDateFormat,
    String timeFormat = defaultTimeFormat,
    this.throwOnSave = false,
  })  : _themeMode = themeMode,
        _dateFormat = dateFormat,
        _timeFormat = timeFormat;

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
}
