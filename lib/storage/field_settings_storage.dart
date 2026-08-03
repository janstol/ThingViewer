import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/field_chart_settings.dart';
import 'storage_recovery.dart';

const _kFieldChartSettingsKey = 'fieldChartSettings';

/// Persists per-field chart presentation overrides using SharedPreferences.
///
/// Keyed by `<serverUrl>|<channelId>|<fieldId>` — `|` is safe as a separator
/// because RFC 3986 never permits it unencoded inside a URI, so it cannot
/// occur inside [Channel.serverUrl].
class FieldSettingsStorage {
  final SharedPreferences _prefs;
  late Map<String, FieldChartSettings> _settings;
  StorageIssue? _issue;

  FieldSettingsStorage(this._prefs) {
    _applyLoad(_load(_prefs));
  }

  StorageIssue? get issue => _issue;

  String? get corruptRaw => quarantinedRaw(_prefs, _kFieldChartSettingsKey);

  Future<void> discardCorrupt() async {
    await clearQuarantine(_prefs, _kFieldChartSettingsKey);
    await _prefs.remove(_kFieldChartSettingsKey);
    reload();
  }

  static LoadOutcome<Map<String, FieldChartSettings>> _load(
    SharedPreferences prefs,
  ) => decodeStoredMap(
    prefs,
    _kFieldChartSettingsKey,
    FieldChartSettings.fromJson,
  );

  void _applyLoad(LoadOutcome<Map<String, FieldChartSettings>> outcome) {
    _settings = outcome.value;
    _issue = outcome.issue;
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
    await _persist();
  }

  /// Re-keys every entry stored under [from]'s identity onto [to]'s, for
  /// when an edited channel's server URL and/or id changes.
  Future<void> migrateChannel(Channel from, Channel to) async {
    final prefix = '${from.serverUrl}|${from.id}|';
    final matching = _settings.keys.where((k) => k.startsWith(prefix)).toList();
    if (matching.isEmpty) return;
    for (final key in matching) {
      final fieldIdSuffix = key.substring(prefix.length);
      _settings['${to.serverUrl}|${to.id}|$fieldIdSuffix'] = _settings.remove(
        key,
      )!;
    }
    await _persist();
  }

  Future<void> _persist() => _prefs.setString(
    _kFieldChartSettingsKey,
    jsonEncode(_settings.map((k, v) => MapEntry(k, v.toJson()))),
  );

  Map<String, dynamic> exportJson() =>
      _settings.map((k, v) => MapEntry(k, v.toJson()));

  Future<void> importJson(Map<String, dynamic> json) async {
    _settings
      ..clear()
      ..addAll({
        for (final entry in json.entries)
          if (entry.value is Map<String, dynamic>)
            entry.key: FieldChartSettings.fromJson(
              entry.value as Map<String, dynamic>,
            ),
      });
    await _persist();
  }

  /// Re-reads the in-memory cache from [_prefs], picking up any changes
  /// written directly to storage (e.g. by a backup restore) since construction.
  void reload() => _applyLoad(_load(_prefs));
}
