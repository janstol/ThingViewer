import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';

const _kChannelsKey = 'channels';

/// Persists the list of saved channels using SharedPreferences.
class ChannelStorage {
  final SharedPreferences _prefs;

  ChannelStorage(this._prefs);

  List<Channel> loadChannels() {
    final raw = _prefs.getString(_kChannelsKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      return Channel.listFromJson(raw);
    } catch (_) {
      return [];
    }
  }

  Future<void> saveChannels(List<Channel> channels) async {
    await _prefs.setString(_kChannelsKey, Channel.listToJson(channels));
  }
}
