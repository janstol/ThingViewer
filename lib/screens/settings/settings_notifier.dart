import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/channel.dart';
import '../../storage/settings_storage.dart';

class SettingsNotifier extends ChangeNotifier {
  final SettingsStorage _storage;

  late ThemeMode _themeMode;
  late String _dateFormat;
  late String _timeFormat;
  late TimezoneDisplay _timezoneDisplay;
  late int? _startChannelId;
  late String? _startChannelServerUrl;

  DateFormat? _cachedDateFmt;
  DateFormat? _cachedDateTimeFmt;

  SettingsNotifier(this._storage) {
    _themeMode = _storage.themeMode;
    _dateFormat = _storage.dateFormat;
    _timeFormat = _storage.timeFormat;
    _timezoneDisplay = _storage.timezoneDisplay;
    _startChannelId = _storage.startChannelId;
    _startChannelServerUrl = _storage.startChannelServerUrl;
  }

  ThemeMode get themeMode => _themeMode;
  String get dateFormat => _dateFormat;
  String get timeFormat => _timeFormat;
  TimezoneDisplay get timezoneDisplay => _timezoneDisplay;

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
    _cachedDateFmt = null;
    _cachedDateTimeFmt = null;
    notifyListeners();
    try {
      await _storage.saveDateFormat(format);
    } catch (_) {
      _dateFormat = previous;
      _cachedDateFmt = null;
      _cachedDateTimeFmt = null;
      notifyListeners();
    }
  }

  Future<void> setTimeFormat(String format) async {
    final previous = _timeFormat;
    _timeFormat = format;
    _cachedDateTimeFmt = null;
    notifyListeners();
    try {
      await _storage.saveTimeFormat(format);
    } catch (_) {
      _timeFormat = previous;
      _cachedDateTimeFmt = null;
      notifyListeners();
    }
  }

  Future<void> setTimezoneDisplay(TimezoneDisplay value) async {
    final previous = _timezoneDisplay;
    _timezoneDisplay = value;
    notifyListeners();
    try {
      await _storage.saveTimezoneDisplay(value);
    } catch (_) {
      _timezoneDisplay = previous;
      notifyListeners();
    }
  }

  /// Formats [dt] as a date only, never with a timezone suffix.
  String formatDate(DateTime dt) =>
      (_cachedDateFmt ??= DateFormat(_dateFormat)).format(dt);

  /// Formats [dt] as date + time, with a timezone suffix per [timezoneDisplay].
  String formatDateTime(DateTime dt) {
    final fmt = _cachedDateTimeFmt ??= DateFormat('$_dateFormat $_timeFormat');
    return '${fmt.format(dt)}${_timezoneSuffix(dt)}';
  }

  String _timezoneSuffix(DateTime dt) {
    switch (_timezoneDisplay) {
      case TimezoneDisplay.off:
        return '';
      case TimezoneDisplay.name:
        final name = dt.timeZoneName.trim();
        if (name.isNotEmpty) return ' $name';
        return ' ${_formatOffset(dt.timeZoneOffset)}'; // fallback
      case TimezoneDisplay.offset:
        return ' ${_formatOffset(dt.timeZoneOffset)}';
    }
  }

  static String _formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
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

  /// Whether [channel] is the currently configured start channel.
  bool isStartChannel(Channel channel) =>
      channel.id == _startChannelId &&
      channel.serverUrl == _startChannelServerUrl;
}
