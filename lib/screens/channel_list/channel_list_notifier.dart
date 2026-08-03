import 'package:flutter/material.dart';

import '../../models/channel.dart';
import '../../storage/channel_storage.dart';
import '../../storage/storage_recovery.dart';

sealed class ChannelListState {}

class ChannelListLoading extends ChannelListState {}

class ChannelListLoaded extends ChannelListState {
  final List<Channel> channels;

  /// Set when the channel list itself was only partially readable — some
  /// entries were dropped. `null` means a fully clean read.
  final StorageIssue? issue;

  ChannelListLoaded(this.channels, {this.issue});
}

/// The stored channel list could not be decoded at all — as opposed to
/// [ChannelListLoaded], which covers both a clean read and a partial salvage.
class ChannelListCorrupted extends ChannelListState {
  final StorageIssue issue;
  ChannelListCorrupted(this.issue);
}

class ChannelListError extends ChannelListState {
  final String message;
  ChannelListError(this.message);
}

class ChannelListNotifier extends ChangeNotifier {
  final ChannelStorage _storage;

  ChannelListState _state = ChannelListLoading();
  ChannelListState get state => _state;

  List<Channel> _channels = [];
  StorageIssue? _issue;

  ChannelListNotifier(this._storage) {
    _loadChannels();
  }

  /// Re-reads the channel list from storage, e.g. after a backup restore.
  void reload() => _loadChannels();

  void _loadChannels() {
    try {
      final outcome = _storage.load();
      _channels = outcome.value;
      _issue = outcome.issue;
      _state = _issue?.total == true
          ? ChannelListCorrupted(_issue!)
          : ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    } catch (e) {
      _state = ChannelListError(e.toString());
    }
    notifyListeners();
  }

  Future<void> addChannel(Channel channel) async {
    // Channel is already enriched by ChannelAddScreen before being passed here
    _channels.add(channel);
    await _storage.saveChannels(_channels);
    _state = ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    notifyListeners();
  }

  Future<void> removeChannel(Channel channel) async {
    _channels.removeWhere((c) => c == channel);
    await _storage.saveChannels(_channels);
    _state = ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    notifyListeners();
  }

  Future<void> updateChannel(Channel channel) async {
    final index = _channels.indexWhere((c) => c == channel);
    if (index == -1) return;
    _channels[index] = channel;
    await _storage.saveChannels(_channels);
    _state = ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    notifyListeners();
  }

  /// Replaces [original] with [updated], which may differ in identity
  /// (id and/or serverUrl) — unlike [updateChannel], which assumes identity
  /// never changes.
  Future<void> replaceChannel(Channel original, Channel updated) async {
    final index = _channels.indexWhere((c) => c == original);
    if (index == -1) return;
    _channels[index] = updated;
    await _storage.saveChannels(_channels);
    _state = ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    notifyListeners();
  }

  /// `newIndex` is the target position *after* the item at `oldIndex` has
  /// been removed, matching `ReorderableListView.onReorderItem`.
  Future<void> reorderChannels(int oldIndex, int newIndex) async {
    final channel = _channels.removeAt(oldIndex);
    _channels.insert(newIndex, channel);
    await _storage.saveChannels(_channels);
    _state = ChannelListLoaded(List.unmodifiable(_channels), issue: _issue);
    notifyListeners();
  }
}
