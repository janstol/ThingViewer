import 'package:flutter/material.dart';

import '../../models/channel.dart';
import '../../storage/settings_storage.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsStorage _storage;

  late ThemeMode _themeMode;
  late String _dateFormat;
  late String _timeFormat;
  late int? _startChannelId;
  late String? _startChannelServerUrl;

  SettingsNotifier(this._storage) {
    _themeMode = _storage.themeMode;
    _dateFormat = _storage.dateFormat;
    _timeFormat = _storage.timeFormat;
    _startChannelId = _storage.startChannelId;
    _startChannelServerUrl = _storage.startChannelServerUrl;
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

  Future<void> setStartChannel(Channel? channel) async {
    final previousId = _startChannelId;
    final previousServerUrl = _startChannelServerUrl;
    _startChannelId = channel?.id;
    _startChannelServerUrl = channel?.serverUrl;
    notifyListeners();
    try {
      await _storage.saveStartChannel(channel);
    } catch (_) {
      _startChannelId = previousId;
      _startChannelServerUrl = previousServerUrl;
      notifyListeners();
    }
  }

  /// Resolves the stored start-channel identity against [channels].
  /// Returns null when unset, or when the stored channel is no longer present.
  Channel? startChannel(List<Channel> channels) {
    final id = _startChannelId;
    final serverUrl = _startChannelServerUrl;
    if (id == null || serverUrl == null) return null;
    for (final channel in channels) {
      if (channel.id == id && channel.serverUrl == serverUrl) return channel;
    }
    return null;
  }
}
