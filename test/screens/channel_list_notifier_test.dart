import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/screens/channel_list/channel_list_notifier.dart';
import 'package:thingviewer/storage/channel_storage.dart';

// In-memory fake — no SharedPreferences needed.
class _FakeChannelStorage implements ChannelStorage {
  List<Channel> _channels;
  final bool throwOnLoad;

  _FakeChannelStorage({
    List<Channel> initial = const [],
    this.throwOnLoad = false,
  }) : _channels = List.of(initial);

  @override
  List<Channel> loadChannels() {
    if (throwOnLoad) throw Exception('load error');
    return List.of(_channels);
  }

  @override
  Future<void> saveChannels(List<Channel> channels) async {
    _channels = List.of(channels);
  }
}

const _a = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);
const _b = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);
const _c = Channel(
  id: 3,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
);

void main() {
  group('initial load', () {
    test('is ChannelListLoaded with saved channels', () {
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(initial: [_a, _b]),
      );
      expect(notifier.state, isA<ChannelListLoaded>());
      expect((notifier.state as ChannelListLoaded).channels, [_a, _b]);
      notifier.dispose();
    });

    test('is ChannelListLoaded with empty list when storage is empty', () {
      final notifier = ChannelListNotifier(_FakeChannelStorage());
      expect(notifier.state, isA<ChannelListLoaded>());
      expect((notifier.state as ChannelListLoaded).channels, isEmpty);
      notifier.dispose();
    });

    test('is ChannelListError when storage throws', () {
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(throwOnLoad: true),
      );
      expect(notifier.state, isA<ChannelListError>());
      notifier.dispose();
    });
  });

  group('addChannel', () {
    test('appends channel and persists', () async {
      final storage = _FakeChannelStorage();
      final notifier = ChannelListNotifier(storage);

      await notifier.addChannel(_a);

      final state = notifier.state as ChannelListLoaded;
      expect(state.channels, [_a]);
      expect(storage.loadChannels(), [_a]);
      notifier.dispose();
    });
  });

  group('removeChannel', () {
    test('removes channel and persists', () async {
      final storage = _FakeChannelStorage(initial: [_a, _b]);
      final notifier = ChannelListNotifier(storage);

      await notifier.removeChannel(_a);

      final state = notifier.state as ChannelListLoaded;
      expect(state.channels, [_b]);
      expect(storage.loadChannels(), [_b]);
      notifier.dispose();
    });

    test('is a no-op for a channel not in the list', () async {
      final storage = _FakeChannelStorage(initial: [_a]);
      final notifier = ChannelListNotifier(storage);

      await notifier.removeChannel(_b);

      expect((notifier.state as ChannelListLoaded).channels, [_a]);
      notifier.dispose();
    });
  });

  group('replaceChannel', () {
    test('replaces channel in place, keeping list position', () async {
      final storage = _FakeChannelStorage(initial: [_a, _b, _c]);
      final notifier = ChannelListNotifier(storage);

      const updated = Channel(
        id: 99,
        serverUrl: 'https://example.com',
        isPublic: true,
        name: 'Renumbered',
      );
      await notifier.replaceChannel(_b, updated);

      final state = notifier.state as ChannelListLoaded;
      expect(state.channels, [_a, updated, _c]);
      expect(storage.loadChannels(), [_a, updated, _c]);
      notifier.dispose();
    });

    test('is a no-op for a channel not in the list', () async {
      final storage = _FakeChannelStorage(initial: [_a]);
      final notifier = ChannelListNotifier(storage);

      await notifier.replaceChannel(_b, _c);

      expect((notifier.state as ChannelListLoaded).channels, [_a]);
      notifier.dispose();
    });
  });

  group('reorderChannels', () {
    // ReorderableListView.onReorderItem passes (oldIndex, newIndex) where
    // newIndex is already the target position *after* removing the item.

    test('moves item down correctly', () async {
      // [A, B, C] drag A (0) to after C → newIndex = 2
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(initial: [_a, _b, _c]),
      );

      await notifier.reorderChannels(0, 2);

      expect((notifier.state as ChannelListLoaded).channels, [_b, _c, _a]);
      notifier.dispose();
    });

    test('moves item up correctly', () async {
      // [A, B, C] drag C (2) to before A → newIndex = 0
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(initial: [_a, _b, _c]),
      );

      await notifier.reorderChannels(2, 0);

      expect((notifier.state as ChannelListLoaded).channels, [_c, _a, _b]);
      notifier.dispose();
    });

    test('moves item one position down', () async {
      // [A, B, C] drag A (0) to after B → newIndex = 1
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(initial: [_a, _b, _c]),
      );

      await notifier.reorderChannels(0, 1);

      expect((notifier.state as ChannelListLoaded).channels, [_b, _a, _c]);
      notifier.dispose();
    });

    test('moves item one position up', () async {
      // [A, B, C] drag B (1) to before A → newIndex = 0
      final notifier = ChannelListNotifier(
        _FakeChannelStorage(initial: [_a, _b, _c]),
      );

      await notifier.reorderChannels(1, 0);

      expect((notifier.state as ChannelListLoaded).channels, [_b, _a, _c]);
      notifier.dispose();
    });

    test('persists the new order', () async {
      final storage = _FakeChannelStorage(initial: [_a, _b, _c]);
      final notifier = ChannelListNotifier(storage);

      await notifier.reorderChannels(0, 2); // A → end

      expect(storage.loadChannels(), [_b, _c, _a]);
      notifier.dispose();
    });
  });
}
