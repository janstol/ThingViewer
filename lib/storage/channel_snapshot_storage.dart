import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/channel_snapshot.dart';

const _kChannelSnapshotsKey = 'channelSnapshots';

/// Persists the last-known state of each channel using SharedPreferences.
///
/// Modelled on `FieldSettingsStorage`. Keyed by `<serverUrl>|<channelId>`,
/// same separator rationale as there. Deliberately not part of the backup
/// format — this is derived data, re-populated on the next successful fetch,
/// and would bloat the export.
class ChannelSnapshotStorage {
  final SharedPreferences _prefs;
  final Map<String, ChannelSnapshot> _snapshots;

  ChannelSnapshotStorage(this._prefs) : _snapshots = _load(_prefs);

  static Map<String, ChannelSnapshot> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kChannelSnapshotsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return {
        for (final entry in map.entries)
          entry.key: ChannelSnapshot.fromJson(
            entry.value as Map<String, dynamic>,
          ),
      };
    } catch (_) {
      return {};
    }
  }

  String _key(Channel channel) => '${channel.serverUrl}|${channel.id}';

  ChannelSnapshot? snapshotFor(Channel channel) => _snapshots[_key(channel)];

  Future<void> save(Channel channel, ChannelSnapshot snapshot) async {
    final key = _key(channel);
    final existing = _snapshots[key];
    _snapshots[key] = existing == null ? snapshot : snapshot.mergedWith(existing);
    await _persist();
  }

  Future<void> remove(Channel channel) async {
    if (_snapshots.remove(_key(channel)) != null) await _persist();
  }

  /// Re-keys the entry stored under [from]'s identity onto [to]'s, for when
  /// an edited channel's server URL and/or id changes.
  Future<void> migrateChannel(Channel from, Channel to) async {
    final snapshot = _snapshots.remove(_key(from));
    if (snapshot == null) return;
    _snapshots[_key(to)] = snapshot;
    await _persist();
  }

  Future<void> _persist() => _prefs.setString(
    _kChannelSnapshotsKey,
    jsonEncode(_snapshots.map((k, v) => MapEntry(k, v.toJson()))),
  );

  /// Re-reads the in-memory cache from [_prefs], picking up any changes
  /// written directly to storage since construction.
  void reload() {
    _snapshots
      ..clear()
      ..addAll(_load(_prefs));
  }
}
