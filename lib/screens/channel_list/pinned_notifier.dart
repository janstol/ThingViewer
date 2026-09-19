import 'package:flutter/foundation.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/channel_snapshot.dart';
import '../../models/field.dart';
import '../../models/pinned_field.dart';
import '../../storage/channel_snapshot_storage.dart';
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
  final PinnedField pin;
  final FieldSnapshot? snapshot;
  final PinnedEntryState state;

  const PinnedEntry({
    required this.channel,
    required this.pin,
    required this.snapshot,
    required this.state,
  });
}

FieldSnapshot? _fieldSnapshotFor(ChannelSnapshot? snapshot, int fieldId) {
  if (snapshot == null) return null;
  for (final field in snapshot.fields) {
    if (field.id == fieldId) return field;
  }
  return null;
}

/// Resolves pinned fields against the live channel list and keeps them
/// fresh, reading/writing their values through the shared per-channel
/// [ChannelSnapshotStorage] cache (also used by the channel detail screen).
///
/// Emits cached snapshots immediately so the channel-list dashboard has real
/// values before any network call, then fires one `readFeed` per distinct
/// pinned channel to refresh them.
class PinnedNotifier extends ChangeNotifier {
  final ThingSpeakApi _api;
  final PinnedFieldsStorage _pinsStorage;
  final ChannelSnapshotStorage _snapshotStorage;
  List<Channel> _channels;
  bool _disposed = false;
  int _requestGeneration = 0;

  List<PinnedEntry> _entries = [];
  List<PinnedEntry> get entries => _entries;

  PinnedNotifier(
    this._api,
    this._pinsStorage,
    this._snapshotStorage,
    List<Channel> channels,
  ) : _channels = channels {
    _loadFromCache();
    refresh();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Whether a request started at [generation] has been superseded by a
  /// newer one (setChannels, refresh) or by disposal, so its result must be
  /// dropped before any side effect: the snapshot store or the visible
  /// entries.
  bool _stale(int generation) => _disposed || generation != _requestGeneration;

  /// Drops any in-flight refresh without starting a new one — a
  /// `setChannels`/`refresh` will follow. Used by callers about to mutate
  /// storage (remove/migrate a channel) so a resolving fetch can't re-save
  /// what they're about to delete or re-key.
  void invalidate() {
    _requestGeneration++;
  }

  /// Points this notifier at a new channel list (e.g. after add/remove/edit/
  /// reorder) and re-fetches.
  void setChannels(List<Channel> channels) {
    _channels = channels;
    _loadFromCache();
    refresh();
  }

  void _loadFromCache() {
    final pins = _pinsStorage.pins(_channels);
    _entries = _sort(
      pins.map((pin) {
        final channel = _channels.firstWhere((c) => pin.matches(c));
        final snapshot = _fieldSnapshotFor(
          _snapshotStorage.snapshotFor(channel),
          pin.fieldId,
        );
        return PinnedEntry(
          channel: channel,
          pin: pin,
          snapshot: snapshot,
          state: snapshot?.value == null
              ? PinnedEntryLoading()
              : PinnedEntryValue(),
        );
      }).toList(),
      _channels,
    );
    if (!_disposed) notifyListeners();
  }

  List<PinnedEntry> _sort(List<PinnedEntry> entries, List<Channel> channels) {
    entries.sort((a, b) {
      final channelCompare = channels
          .indexOf(a.channel)
          .compareTo(channels.indexOf(b.channel));
      if (channelCompare != 0) return channelCompare;
      return a.pin.fieldId.compareTo(b.pin.fieldId);
    });
    return entries;
  }

  Future<void> refresh() async {
    final generation = ++_requestGeneration;
    final channels = _channels;
    final pins = _pinsStorage.pins(channels);
    if (pins.isEmpty) return;

    final byChannel = <Channel, List<PinnedField>>{};
    for (final pin in pins) {
      final channel = channels.firstWhere((c) => pin.matches(c));
      byChannel.putIfAbsent(channel, () => []).add(pin);
    }

    final results = await Future.wait(
      byChannel.entries.map((e) => _fetchChannel(generation, e.key, e.value)),
    );
    if (_stale(generation)) return;

    final updated = [for (final r in results) ...r];
    _entries = _sort(updated, channels);
    if (!_disposed) notifyListeners();
  }

  Future<List<PinnedEntry>> _fetchChannel(
    int generation,
    Channel channel,
    List<PinnedField> pins,
  ) async {
    try {
      final feedData = await _api.readFeed(
        channel,
        ApiParameters(apiKey: channel.apiKey, results: 100),
      );
      if (_stale(generation)) return const [];
      var fields = feedData.fields;

      final pinnedIds = pins.map((p) => p.fieldId).toSet();
      final gaps = fields
          .where((f) => pinnedIds.contains(f.id) && f.values.isEmpty)
          .toList();
      if (gaps.isNotEmpty) {
        final recovered = await Future.wait(
          gaps.map((f) => _api.readLastFieldEntry(channel, f.id)),
        );
        if (_stale(generation)) return const [];
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

      // Write the whole feed back, not just the pinned fields — the merge
      // rule in ChannelSnapshot protects non-pinned sparse fields this fetch
      // did not recover (it only recovers gaps for pinned field ids).
      final nonEmpty = fields.where((f) => f.lastValue != null).toList();
      await _snapshotStorage.save(
        channel,
        ChannelSnapshot(
          fields: nonEmpty
              .map(
                (f) => FieldSnapshot(
                  id: f.id,
                  label: f.label,
                  value: f.lastValue,
                  valueAt: f.lastUpdated,
                ),
              )
              .toList(),
          fetchedAt: DateTime.now(),
        ),
      );

      final merged = _snapshotStorage.snapshotFor(channel);
      return [
        for (final pin in pins)
          PinnedEntry(
            channel: channel,
            pin: pin,
            snapshot: _fieldSnapshotFor(merged, pin.fieldId),
            state: PinnedEntryValue(),
          ),
      ];
    } on ApiException catch (e) {
      final cached = _snapshotStorage.snapshotFor(channel);
      return [
        for (final pin in pins)
          PinnedEntry(
            channel: channel,
            pin: pin,
            snapshot: _fieldSnapshotFor(cached, pin.fieldId),
            state: PinnedEntryError(e.code),
          ),
      ];
    }
  }
}
