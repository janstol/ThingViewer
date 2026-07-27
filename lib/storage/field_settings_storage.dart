import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/field_chart_settings.dart';

const _kFieldChartSettingsKey = 'fieldChartSettings';

/// Persists per-field chart presentation overrides using SharedPreferences.
///
/// Keyed by `<serverUrl>|<channelId>|<fieldId>` — `|` is safe as a separator
/// because RFC 3986 never permits it unencoded inside a URI, so it cannot
/// occur inside [Channel.serverUrl].
class FieldSettingsStorage {
  final SharedPreferences _prefs;
  final Map<String, FieldChartSettings> _settings;

  FieldSettingsStorage(this._prefs) : _settings = _load(_prefs);

  static Map<String, FieldChartSettings> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kFieldChartSettingsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in map.entries)
          entry.key:
              FieldChartSettings.fromJson(entry.value as Map<String, dynamic>),
      };
    } catch (_) {
      return {};
    }
  }

  String _key(Channel channel, int fieldId) =>
      '${channel.serverUrl}|${channel.id}|$fieldId';

  FieldChartSettings settingsFor(Channel channel, int fieldId) =>
      _settings[_key(channel, fieldId)] ?? FieldChartSettings.defaults;

  Future<void> save(
    Channel channel,
    int fieldId,
    FieldChartSettings settings,
  ) async {
    final key = _key(channel, fieldId);
    if (settings.isDefault) {
      _settings.remove(key);
    } else {
      _settings[key] = settings;
    }
    await _prefs.setString(
      _kFieldChartSettingsKey,
      jsonEncode(_settings.map((k, v) => MapEntry(k, v.toJson()))),
    );
  }
}
