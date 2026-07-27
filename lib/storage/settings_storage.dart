import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';

const _kThemeModeKey = 'themeMode';
const _kDateFormatKey = 'dateFormat';
const _kTimeFormatKey = 'timeFormat';
const _kStartChannelIdKey = 'startChannelId';
const _kStartChannelServerUrlKey = 'startChannelServerUrl';
const _kTimezoneDisplayKey = 'timezoneDisplay';

const defaultDateFormat = 'dd.MM.yyyy';
const defaultTimeFormat = 'HH:mm';

enum TimezoneDisplay { off, offset, name }

const defaultTimezoneDisplay = TimezoneDisplay.off;

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
}
