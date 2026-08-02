import 'package:flutter/foundation.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../models/pinned_field.dart';
import '../../storage/pinned_fields_storage.dart';

sealed class PinnedEntryState {}

/// No cached value yet and the first fetch hasn't completed.
class PinnedEntryLoading extends PinnedEntryState {}

/// Fetch completed (or a cached snapshot exists) — [PinnedEntry.snapshot]
/// carries the value, which may itself be null if the field has never
/// reported one.
class PinnedEntryValue extends PinnedEntryState {}

/// The pin's channel failed to fetch — [PinnedEntry.snapshot] still carries
/// whatever was last cached.
class PinnedEntryError extends PinnedEntryState {
  final ApiErrorCode errorCode;
  PinnedEntryError(this.errorCode);
}

class PinnedEntry {
  final Channel channel;
  final PinnedField snapshot;
  final PinnedEntryState state;

  const PinnedEntry({
    required this.channel,
    required this.snapshot,
    required this.state,
  });
}

/// Resolves pinned fields against the live channel list and keeps their
/// cached value/age snapshots fresh.
///
/// Emits cached snapshots immediately (from [PinnedFieldsStorage]) so the
/// channel-list dashboard has real values before any network call, then
/// fires one `readFeed` per distinct pinned channel to refresh them.
class PinnedNotifier extends ChangeNotifier {
  final ThingSpeakApi _api;
  final PinnedFieldsStorage _storage;
  List<Channel> _channels;
  bool _disposed = false;

  List<PinnedEntry> _entries = [];
  List<PinnedEntry> get entries => _entries;

  PinnedNotifier(this._api, this._storage, List<Channel> channels)
    : _channels = channels {
    _loadFromCache();
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Points this notifier at a new channel list (e.g. after add/remove/edit/
  /// reorder) and re-fetches.
  void setChannels(List<Channel> channels) {
    _channels = channels;
    _loadFromCache();
    refresh();
  }

  void _loadFromCache() {
    final pins = _storage.pins(_channels);
    _entries = _sort(
      pins.map((pin) {
        final channel = _channels.firstWhere((c) => pin.matches(c));
        return PinnedEntry(
          channel: channel,
          snapshot: pin,
          state: pin.value == null ? PinnedEntryLoading() : PinnedEntryValue(),
        );
      }).toList(),
    );
    if (!_disposed) notifyListeners();
  }

  List<PinnedEntry> _sort(List<PinnedEntry> entries) {
    entries.sort((a, b) {
      final channelCompare = _channels
          .indexOf(a.channel)
          .compareTo(_channels.indexOf(b.channel));
      if (channelCompare != 0) return channelCompare;
      return a.snapshot.fieldId.compareTo(b.snapshot.fieldId);
    });
    return entries;
  }

  Future<void> refresh() async {
    final pins = _storage.pins(_channels);
    if (pins.isEmpty) return;

    final byChannel = <Channel, List<PinnedField>>{};
    for (final pin in pins) {
      final channel = _channels.firstWhere((c) => pin.matches(c));
      byChannel.putIfAbsent(channel, () => []).add(pin);
    }

    final results = await Future.wait(
      byChannel.entries.map((e) => _fetchChannel(e.key, e.value)),
    );

    final updated = [for (final r in results) ...r];
    _entries = _sort(updated);
    if (!_disposed) notifyListeners();

    final snapshots = [
      for (final entry in updated)
        if (entry.state is PinnedEntryValue) entry.snapshot,
    ];
    if (snapshots.isNotEmpty) await _storage.saveSnapshots(snapshots);
  }

  Future<List<PinnedEntry>> _fetchChannel(
    Channel channel,
    List<PinnedField> pins,
  ) async {
    try {
      final feedData = await _api.readFeed(
        channel,
        ApiParameters(apiKey: channel.apiKey, results: 100),
      );
      var fields = feedData.fields;

      final pinnedIds = pins.map((p) => p.fieldId).toSet();
      final gaps = fields
          .where((f) => pinnedIds.contains(f.id) && f.values.isEmpty)
          .toList();
      if (gaps.isNotEmpty) {
        final recovered = await Future.wait(
          gaps.map((f) => _api.readLastFieldEntry(channel, f.id)),
        );
        final recoveredById = {
          for (var i = 0; i < gaps.length; i++)
            if (recovered[i] != null) gaps[i].id: recovered[i]!,
        };
        if (recoveredById.isNotEmpty) {
          fields = fields
              .map(
                (f) => recoveredById.containsKey(f.id)
                    ? Field(
                        id: f.id,
                        label: f.label,
                        values: [recoveredById[f.id]!],
                        invalidAt: f.invalidAt,
                      )
                    : f,
              )
              .toList();
        }
      }

      final fieldsById = {for (final f in fields) f.id: f};
      final now = DateTime.now();
      return [
        for (final pin in pins)
          PinnedEntry(
            channel: channel,
            snapshot: pin.copyWith(
              label: fieldsById[pin.fieldId]?.displayLabel,
              value: fieldsById[pin.fieldId]?.lastValue,
              valueAt: fieldsById[pin.fieldId]?.lastUpdated,
              fetchedAt: now,
            ),
            state: PinnedEntryValue(),
          ),
      ];
    } on ApiException catch (e) {
      return [
        for (final pin in pins)
          PinnedEntry(channel: channel, snapshot: pin, state: PinnedEntryError(e.code)),
      ];
    }
  }
}
