import 'package:flutter/material.dart';

import '../../storage/settings_storage.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsStorage _storage;

  late ThemeMode _themeMode;
  late String _dateFormat;
  late String _timeFormat;

  SettingsNotifier(this._storage) {
    _themeMode = _storage.themeMode;
    _dateFormat = _storage.dateFormat;
    _timeFormat = _storage.timeFormat;
  }

  ThemeMode get themeMode => _themeMode;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;

  Future<void> setThemeMode(ThemeMode mode) async {
    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();
    try {
      await _storage.saveThemeMode(mode);
    } catch (_) {
      _themeMode = previous;
      notifyListeners();
    }
  }

  Future<void> setDateFormat(String format) async {
    final previous = _dateFormat;
    _dateFormat = format;
    notifyListeners();
    try {
      await _storage.saveDateFormat(format);
    } catch (_) {
      _dateFormat = previous;
      notifyListeners();
    }
  }

  Future<void> setTimeFormat(String format) async {
    final previous = _timeFormat;
    _timeFormat = format;
    notifyListeners();
    try {
      await _storage.saveTimeFormat(format);
    } catch (_) {
      _timeFormat = previous;
      notifyListeners();
    }
  }
}
