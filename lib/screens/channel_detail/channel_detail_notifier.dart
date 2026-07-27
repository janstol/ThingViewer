import 'package:flutter/foundation.dart';

import '../../api/thingspeak_api.dart';
import '../../models/channel.dart';
import '../../models/field.dart';

sealed class ChannelDetailState {}

class ChannelDetailLoading extends ChannelDetailState {}

class ChannelDetailLoaded extends ChannelDetailState {
  final Channel channel;
  final List<Field> fields;
  ChannelDetailLoaded(this.channel, this.fields);
}

class ChannelDetailEmpty extends ChannelDetailState {
  final Channel channel;
  ChannelDetailEmpty(this.channel);
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

  Future<void> _fetch() async {
    try {
      final params = ApiParameters(apiKey: _channel.apiKey, results: 100);
      final updated = await _api.readChannel(_channel);
      final fields = await _api.readFeed(updated, params);
      _channel = updated;
      onChannelUpdated?.call(updated);

      final nonEmpty = fields.where((f) => f.lastValue != null).toList();
      _state = nonEmpty.isEmpty
          ? ChannelDetailEmpty(updated)
          : ChannelDetailLoaded(updated, nonEmpty);
    } on ApiException catch (e) {
      _state = ChannelDetailError(_channel, e.code, e.serverMessage);
    }
    if (!_disposed) notifyListeners();
  }
}
