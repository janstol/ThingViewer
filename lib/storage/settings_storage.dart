import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kThemeModeKey = 'themeMode';
const _kDateFormatKey = 'dateFormat';
const _kTimeFormatKey = 'timeFormat';

const defaultDateFormat = 'dd.MM.yyyy';
const defaultTimeFormat = 'HH:mm';

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
}
