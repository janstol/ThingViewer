import 'package:flutter/foundation.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/channel_snapshot.dart';
import '../../models/channel_status.dart';
import '../../models/field.dart';
import '../../storage/channel_snapshot_storage.dart';

sealed class ChannelDetailState {}

class ChannelDetailLoading extends ChannelDetailState {}

class ChannelDetailLoaded extends ChannelDetailState {
  final Channel channel;
  final List<Field> fields;
  final List<ChannelStatus> statuses;

  /// Non-null when [fields] came from the cache rather than a completed
  /// fetch, the time that cache was written.
  final DateTime? cachedAt;

  /// Whether a fetch is in flight to replace these (possibly cached) values.
  final bool refreshing;

  /// Set when the latest refresh attempt failed while cached values stayed
  /// on screen, so the banner can report it without discarding the values.
  final ApiErrorCode? refreshError;

  ChannelDetailLoaded(
    this.channel,
    this.fields,
    this.statuses, {
    this.cachedAt,
    this.refreshing = false,
    this.refreshError,
  });
}

class ChannelDetailEmpty extends ChannelDetailState {
  final Channel channel;
  final List<ChannelStatus> statuses;
  ChannelDetailEmpty(this.channel, this.statuses);
}

class ChannelDetailError extends ChannelDetailState {
  final Channel channel;
  final ApiErrorCode errorCode;
  final String? serverMessage;
  ChannelDetailError(this.channel, this.errorCode, [this.serverMessage]);
}

class ChannelDetailNotifier extends ChangeNotifier {
  final ThingSpeakApi _api;
  final ChannelSnapshotStorage _snapshotStorage;
  final void Function(Channel)? onChannelUpdated;
  Channel _channel;
  bool _disposed = false;
  int _requestGeneration = 0;

  ChannelDetailState _state = ChannelDetailLoading();
  ChannelDetailState get state => _state;

  ChannelDetailNotifier(
    this._api,
    this._snapshotStorage,
    this._channel, {
    this.onChannelUpdated,
  }) {
    final cached = _loadedFromCache();
    _state = cached ?? ChannelDetailLoading();
    _fetch();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// Whether a request started at [generation] has been superseded by a
  /// newer one (reload, edit) or by disposal, so its result must be dropped
  /// before any side effect: `_channel`, `onChannelUpdated`, the snapshot
  /// store, or the visible state.
  bool _stale(int generation) => _disposed || generation != _requestGeneration;

  /// Builds a [ChannelDetailLoaded] from the channel's cached snapshot, or
  /// null if there is no snapshot or it has no field with a value.
  ChannelDetailLoaded? _loadedFromCache() {
    final snapshot = _snapshotStorage.snapshotFor(_channel);
    if (snapshot == null) return null;
    final fields = snapshot.fields
        .where((f) => f.value != null)
        .map(
          (f) => Field(
            id: f.id,
            label: f.label,
            values: [FieldValue(createdAt: f.valueAt!, value: f.value!)],
          ),
        )
        .toList();
    if (fields.isEmpty) return null;
    return ChannelDetailLoaded(
      _channel,
      fields,
      snapshot.statuses,
      cachedAt: snapshot.fetchedAt,
      refreshing: true,
    );
  }

  /// Re-fetches, keeping cached/loaded content on screen with `refreshing`
  /// set rather than dropping to [ChannelDetailLoading].
  Future<void> load() async {
    final current = _state;
    if (current is ChannelDetailLoaded) {
      _state = ChannelDetailLoaded(
        _channel,
        current.fields,
        current.statuses,
        cachedAt: current.cachedAt,
        refreshing: true,
      );
    } else {
      _state = ChannelDetailLoading();
    }
    notifyListeners();
    await _fetch();
  }

  /// Re-fetches without changing state first, since the caller (a
  /// pull-to-refresh gesture) renders its own progress indicator.
  Future<void> refresh() => _fetch();

  /// Points this notifier at a different channel (e.g. after editing it) and
  /// reloads from scratch.
  Future<void> setChannel(Channel channel) async {
    _channel = channel;
    final cached = _loadedFromCache();
    _state = cached ?? ChannelDetailLoading();
    notifyListeners();
    await _fetch();
  }

  Future<void> _fetch() async {
    final generation = ++_requestGeneration;
    // The request's own channel: an edit via setChannel mid-request must not
    // leak the new key into this request's follow-up calls.
    final channel = _channel;
    try {
      final params = ApiParameters(
        apiKey: channel.apiKey,
        results: 100,
        status: true,
      );
      final results = await Future.wait([
        _api.readChannel(channel),
        _api.readFeed(channel, params),
      ]);
      if (_stale(generation)) return;
      final updated = results[0] as Channel;
      final feedData = results[1] as FeedData;
      _channel = updated.copyWith(authError: false);
      onChannelUpdated?.call(_channel);

      var fields = feedData.fields;
      final gaps = fields.where((f) => f.values.isEmpty).toList();
      if (gaps.isNotEmpty) {
        final recovered = await Future.wait(
          gaps.map((f) => _api.readLastFieldEntry(channel, f.id)),
        );
        if (_stale(generation)) return;
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

      final nonEmpty = fields.where((f) => f.lastValue != null).toList();
      final fetchedAt = DateTime.now();
      await _snapshotStorage.save(
        _channel,
        ChannelSnapshot(
          description: _channel.description,
          url: _channel.url,
          githubUrl: _channel.githubUrl,
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
          statuses: feedData.statuses,
          fetchedAt: fetchedAt,
        ),
      );
      if (_stale(generation)) return;
      _state = nonEmpty.isEmpty
          ? ChannelDetailEmpty(_channel, feedData.statuses)
          : ChannelDetailLoaded(_channel, nonEmpty, feedData.statuses);
    } on ApiException catch (e) {
      if (_stale(generation)) return;
      if (e.code == ApiErrorCode.credentials && !_channel.authError) {
        _channel = _channel.copyWith(authError: true);
        onChannelUpdated?.call(_channel);
      }
      final current = _state;
      if (current is ChannelDetailLoaded) {
        // The data on screen (live or cache-loaded) was necessarily saved to
        // the snapshot store already, so it is the source of truth for how
        // old it is now that this refresh failed to replace it.
        final cachedAt =
            _snapshotStorage.snapshotFor(_channel)?.fetchedAt ??
            current.cachedAt;
        _state = ChannelDetailLoaded(
          _channel,
          current.fields,
          current.statuses,
          cachedAt: cachedAt,
          refreshError: e.code,
        );
      } else {
        _state = ChannelDetailError(_channel, e.code, e.serverMessage);
      }
    }
    if (!_disposed) notifyListeners();
  }
}
