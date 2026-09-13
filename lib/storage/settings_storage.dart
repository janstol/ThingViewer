import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';

const _kThemeModeKey = 'themeMode';
const _kDateFormatKey = 'dateFormat';
const _kTimeFormatKey = 'timeFormat';
const _kStartChannelIdKey = 'startChannelId';
const _kStartChannelServerUrlKey = 'startChannelServerUrl';
const _kTimezoneDisplayKey = 'timezoneDisplay';
const _kEntryTimeDisplayKey = 'entryTimeDisplay';

const defaultDateFormat = 'dd.MM.yyyy';
const defaultTimeFormat = 'HH:mm';

enum TimezoneDisplay { off, offset, name }

const defaultTimezoneDisplay = TimezoneDisplay.off;

enum EntryTimeDisplay { absolute, age, both }

const defaultEntryTimeDisplay = EntryTimeDisplay.both;

/// Every key [SettingsStorage.importJson] can write, for
/// [SettingsStorage.snapshotForImport] to capture and
/// [SettingsStorage.restoreSnapshot] to roll back — kept here rather than
/// duplicated by a caller since these key constants are private to this file.
const _kImportableKeys = [
  _kThemeModeKey,
  _kDateFormatKey,
  _kTimeFormatKey,
  _kTimezoneDisplayKey,
  _kEntryTimeDisplayKey,
  _kStartChannelIdKey,
  _kStartChannelServerUrlKey,
];

/// Persists user preferences using SharedPreferences.
class SettingsStorage {
  final SharedPreferences _prefs;

  SettingsStorage(this._prefs);

  ThemeMode get themeMode {
    final value = _prefs.getInt(_kThemeModeKey);
    return ThemeMode.values.elementAtOrNull(value ?? 0) ?? ThemeMode.system;
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_kThemeModeKey, mode.index);
  }

  String get dateFormat =>
      _prefs.getString(_kDateFormatKey) ?? defaultDateFormat;

  Future<void> saveDateFormat(String format) async {
    await _prefs.setString(_kDateFormatKey, format);
  }

  String get timeFormat =>
      _prefs.getString(_kTimeFormatKey) ?? defaultTimeFormat;

  Future<void> saveTimeFormat(String format) async {
    await _prefs.setString(_kTimeFormatKey, format);
  }

  TimezoneDisplay get timezoneDisplay =>
      TimezoneDisplay.values.elementAtOrNull(
        _prefs.getInt(_kTimezoneDisplayKey) ?? 0,
      ) ??
      defaultTimezoneDisplay;

  Future<void> saveTimezoneDisplay(TimezoneDisplay value) async {
    await _prefs.setInt(_kTimezoneDisplayKey, value.index);
  }

  EntryTimeDisplay get entryTimeDisplay =>
      EntryTimeDisplay.values.elementAtOrNull(
        _prefs.getInt(_kEntryTimeDisplayKey) ?? defaultEntryTimeDisplay.index,
      ) ??
      defaultEntryTimeDisplay;

  Future<void> saveEntryTimeDisplay(EntryTimeDisplay value) async {
    await _prefs.setInt(_kEntryTimeDisplayKey, value.index);
  }

  int? get startChannelId => _prefs.getInt(_kStartChannelIdKey);

  String? get startChannelServerUrl =>
      _prefs.getString(_kStartChannelServerUrlKey);

  Future<void> saveStartChannel(Channel? channel) async {
    if (channel == null) {
      await _prefs.remove(_kStartChannelIdKey);
      await _prefs.remove(_kStartChannelServerUrlKey);
    } else {
      await _prefs.setInt(_kStartChannelIdKey, channel.id);
      await _prefs.setString(_kStartChannelServerUrlKey, channel.serverUrl);
    }
  }

  Map<String, dynamic> exportJson() => {
    _kThemeModeKey: themeMode.index,
    _kDateFormatKey: dateFormat,
    _kTimeFormatKey: timeFormat,
    _kTimezoneDisplayKey: timezoneDisplay.index,
    _kEntryTimeDisplayKey: entryTimeDisplay.index,
    if (startChannelId != null) _kStartChannelIdKey: startChannelId,
    if (startChannelServerUrl != null)
      _kStartChannelServerUrlKey: startChannelServerUrl,
  };

  /// Writes each key defensively: absent or wrong-typed values are skipped
  /// rather than throwing, and enum-backed values are clamped to their valid
  /// range, mirroring [MigrationService._migrateSettings].
  Future<void> importJson(Map<String, dynamic> json) async {
    final themeModeValue = json[_kThemeModeKey];
    if (themeModeValue is int) {
      await _prefs.setInt(_kThemeModeKey, themeModeValue.clamp(0, 2));
    }
    final dateFormatValue = json[_kDateFormatKey];
    if (dateFormatValue is String) {
      await _prefs.setString(_kDateFormatKey, dateFormatValue);
    }
    final timeFormatValue = json[_kTimeFormatKey];
    if (timeFormatValue is String) {
      await _prefs.setString(_kTimeFormatKey, timeFormatValue);
    }
    final timezoneDisplayValue = json[_kTimezoneDisplayKey];
    if (timezoneDisplayValue is int) {
      await _prefs.setInt(
        _kTimezoneDisplayKey,
        timezoneDisplayValue.clamp(0, TimezoneDisplay.values.length - 1),
      );
    }
    final entryTimeDisplayValue = json[_kEntryTimeDisplayKey];
    if (entryTimeDisplayValue is int) {
      await _prefs.setInt(
        _kEntryTimeDisplayKey,
        entryTimeDisplayValue.clamp(0, EntryTimeDisplay.values.length - 1),
      );
    }
    final startChannelIdValue = json[_kStartChannelIdKey];
    if (startChannelIdValue is int) {
      await _prefs.setInt(_kStartChannelIdKey, startChannelIdValue);
    }
    final startChannelServerUrlValue = json[_kStartChannelServerUrlKey];
    if (startChannelServerUrlValue is String) {
      await _prefs.setString(
        _kStartChannelServerUrlKey,
        startChannelServerUrlValue,
      );
    }
  }

  /// Captures the current raw value of every key [importJson] can write, so
  /// a failed import can be rolled back with [restoreSnapshot].
  Map<String, Object?> snapshotForImport() => {
    for (final key in _kImportableKeys) key: _prefs.get(key),
  };

  /// Restores a snapshot taken by [snapshotForImport], removing any key that
  /// was absent at snapshot time.
  Future<void> restoreSnapshot(Map<String, Object?> snapshot) async {
    for (final entry in snapshot.entries) {
      final value = entry.value;
      if (value == null) {
        await _prefs.remove(entry.key);
      } else if (value is int) {
        await _prefs.setInt(entry.key, value);
      } else if (value is String) {
        await _prefs.setString(entry.key, value);
      }
    }
  }
}
