import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import '../models/pinned_field.dart';
import 'storage_recovery.dart';

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
  late List<PinnedField> _pins;
  StorageIssue? _issue;

  PinnedFieldsStorage(this._prefs) {
    _applyLoad(_load(_prefs));
  }

  StorageIssue? get issue => _issue;

  String? get corruptRaw => quarantinedRaw(_prefs, _kPinnedFieldsKey);

  Future<void> discardCorrupt() async {
    await clearQuarantine(_prefs, _kPinnedFieldsKey);
    await _prefs.remove(_kPinnedFieldsKey);
    reload();
  }

  static LoadOutcome<List<PinnedField>> _load(SharedPreferences prefs) =>
      decodeStoredList(prefs, _kPinnedFieldsKey, PinnedField.fromJson);

  void _applyLoad(LoadOutcome<List<PinnedField>> outcome) {
    _pins = outcome.value;
    _issue = outcome.issue;
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
  void reload() => _applyLoad(_load(_prefs));
}
