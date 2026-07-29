import 'package:flutter/foundation.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/channel_status.dart';
import '../../models/field.dart';

sealed class ChannelDetailState {}

class ChannelDetailLoading extends ChannelDetailState {}

class ChannelDetailLoaded extends ChannelDetailState {
  final Channel channel;
  final List<Field> fields;
  final List<ChannelStatus> statuses;
  ChannelDetailLoaded(this.channel, this.fields, this.statuses);
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
  final void Function(Channel)? onChannelUpdated;
  Channel _channel;
  bool _disposed = false;

  ChannelDetailState _state = ChannelDetailLoading();
  ChannelDetailState get state => _state;

  ChannelDetailNotifier(this._api, this._channel, {this.onChannelUpdated}) {
    load();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> load() async {
    _state = ChannelDetailLoading();
    notifyListeners();
    await _fetch();
  }

  /// Re-fetches without setting [ChannelDetailLoading] first, since the
  /// caller (a pull-to-refresh gesture) renders its own progress indicator.
  Future<void> refresh() => _fetch();

  /// Points this notifier at a different channel (e.g. after editing it) and
  /// reloads from scratch.
  Future<void> setChannel(Channel channel) {
    _channel = channel;
    return load();
  }

  Future<void> _fetch() async {
    try {
      final params = ApiParameters(
        apiKey: _channel.apiKey,
        results: 100,
        status: true,
      );
      final results = await Future.wait([
        _api.readChannel(_channel),
        _api.readFeed(_channel, params),
      ]);
      final updated = results[0] as Channel;
      final feedData = results[1] as FeedData;
      _channel = updated.copyWith(authError: false);
      onChannelUpdated?.call(_channel);

      final nonEmpty = feedData.fields
          .where((f) => f.lastValue != null)
          .toList();
      _state = nonEmpty.isEmpty
          ? ChannelDetailEmpty(_channel, feedData.statuses)
          : ChannelDetailLoaded(_channel, nonEmpty, feedData.statuses);
    } on ApiException catch (e) {
      if (e.code == ApiErrorCode.credentials && !_channel.authError) {
        _channel = _channel.copyWith(authError: true);
        onChannelUpdated?.call(_channel);
      }
      _state = ChannelDetailError(_channel, e.code, e.serverMessage);
    }
    if (!_disposed) notifyListeners();
  }
}
