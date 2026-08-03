import 'package:shared_preferences/shared_preferences.dart';

import '../models/channel.dart';
import 'storage_recovery.dart';

const _kChannelsKey = 'channels';

/// Persists the list of saved channels using SharedPreferences.
class ChannelStorage {
  final SharedPreferences _prefs;
  StorageIssue? _issue;

  ChannelStorage(this._prefs);

  StorageIssue? get issue => _issue;

  List<Channel> loadChannels() => load().value;

  LoadOutcome<List<Channel>> load() {
    final outcome = decodeStoredList(_prefs, _kChannelsKey, Channel.fromJson);
    _issue = outcome.issue;
    return outcome;
  }

  Future<void> saveChannels(List<Channel> channels) async {
    await _prefs.setString(_kChannelsKey, Channel.listToJson(channels));
  }

  String? get corruptRaw => quarantinedRaw(_prefs, _kChannelsKey);

  Future<void> discardCorrupt() async {
    await clearQuarantine(_prefs, _kChannelsKey);
    await _prefs.remove(_kChannelsKey);
    _issue = null;
  }
}
