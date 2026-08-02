import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/pinned_field.dart';

const _kPinnedFieldsKey = 'pinnedFields';

/// Persists the ordered list of pinned fields using SharedPreferences.
///
/// Modelled on `FieldSettingsStorage`, but keeps an ordered **list** rather
/// than a map — pin display order follows the channel list, not an
/// independent key ordering. Orphaned pins (channel no longer saved) are
/// filtered at read time against the live channel list rather than pruned on
/// delete, so a deleted-then-re-added channel keeps its pins.
class PinnedFieldsStorage {
  final SharedPreferences _prefs;
  final List<PinnedField> _pins;

  PinnedFieldsStorage(this._prefs) : _pins = _load(_prefs);

  static List<PinnedField> _load(SharedPreferences prefs) {
    final raw = prefs.getString(_kPinnedFieldsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PinnedField.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// All pins whose channel is in [channels], filtering out orphans.
  List<PinnedField> pins(List<Channel> channels) => _pins
      .where((p) => channels.any((c) => p.matches(c)))
      .toList(growable: false);

  bool isPinned(Channel channel, int fieldId) => _pins.any(
    (p) => p.matches(channel) && p.fieldId == fieldId,
  );

  Future<void> toggle(Channel channel, int fieldId) async {
    final index = _pins.indexWhere(
      (p) => p.matches(channel) && p.fieldId == fieldId,
    );
    if (index >= 0) {
      _pins.removeAt(index);
    } else {
      _pins.add(
        PinnedField(
          serverUrl: channel.serverUrl,
          channelId: channel.id,
          fieldId: fieldId,
        ),
      );
    }
    await _persist();
  }

  /// Overwrites the cached snapshot (label/value/valueAt/fetchedAt) for each
  /// pin in [snapshots] that is still pinned, keyed by identity. Pins not
  /// present in [snapshots] are left untouched.
  Future<void> saveSnapshots(List<PinnedField> snapshots) async {
    var changed = false;
    for (final snapshot in snapshots) {
      final index = _pins.indexOf(snapshot);
      if (index >= 0) {
        _pins[index] = snapshot;
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  /// Re-keys every pin stored under [from]'s identity onto [to]'s, for when
  /// an edited channel's server URL and/or id changes.
  Future<void> migrateChannel(Channel from, Channel to) async {
    var changed = false;
    for (var i = 0; i < _pins.length; i++) {
      if (_pins[i].matches(from)) {
        _pins[i] = _pins[i].copyWith(
          serverUrl: to.serverUrl,
          channelId: to.id,
        );
        changed = true;
      }
    }
    if (changed) await _persist();
  }

  Future<void> _persist() => _prefs.setString(
    _kPinnedFieldsKey,
    jsonEncode(_pins.map((p) => p.toJson()).toList()),
  );

  List<dynamic> exportJson() => _pins.map((p) => p.toJson()).toList();

  Future<void> importJson(List<dynamic> json) async {
    _pins
      ..clear()
      ..addAll(
        json
            .whereType<Map<String, dynamic>>()
            .map(PinnedField.fromJson),
      );
    await _persist();
  }

  /// Re-reads the in-memory cache from [_prefs], picking up any changes
  /// written directly to storage (e.g. by a backup restore) since construction.
  void reload() {
    _pins
      ..clear()
      ..addAll(_load(_prefs));
  }
}
