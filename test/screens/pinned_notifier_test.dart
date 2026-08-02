import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/models/pinned_field.dart';
import 'package:thingviewer/screens/channel_list/pinned_notifier.dart';
import 'package:thingviewer/storage/pinned_fields_storage.dart';

import 'pinned_notifier_test.mocks.dart';

const _channelA = Channel(
  id: 1,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Channel A',
);

const _channelB = Channel(
  id: 2,
  serverUrl: 'https://api.thingspeak.com',
  isPublic: true,
  name: 'Channel B',
);

@GenerateMocks([ThingSpeakApi])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockThingSpeakApi mockApi;
  late PinnedFieldsStorage storage;

  Future<PinnedFieldsStorage> seededStorage(
    List<(Channel, int)> pins,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final s = PinnedFieldsStorage(await SharedPreferences.getInstance());
    for (final (channel, fieldId) in pins) {
      await s.toggle(channel, fieldId);
    }
    return s;
  }

  setUp(() {
    mockApi = MockThingSpeakApi();
  });

  test('emits cached snapshots before any network call resolves', () async {
    storage = await seededStorage([(_channelA, 1)]);
    await storage.saveSnapshots([
      const PinnedField(
        serverUrl: 'https://api.thingspeak.com',
        channelId: 1,
        fieldId: 1,
        label: 'Temp',
        value: 21,
      ),
    ]);
    when(mockApi.readFeed(any, any)).thenAnswer(
      (_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return FeedData(fields: const [], statuses: []);
      },
    );

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);

    expect(notifier.entries, hasLength(1));
    expect(notifier.entries.single.snapshot.value, 21);
    expect(notifier.entries.single.state, isA<PinnedEntryValue>());
    notifier.dispose();
  });

  test('a pin with no cached value starts in loading state', () async {
    storage = await seededStorage([(_channelA, 1)]);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: const [], statuses: []));

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);

    expect(notifier.entries.single.state, isA<PinnedEntryLoading>());
    notifier.dispose();
  });

  test('fires one readFeed per distinct pinned channel', () async {
    storage = await seededStorage([
      (_channelA, 1),
      (_channelA, 2),
      (_channelB, 1),
    ]);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: const [], statuses: []));

    final notifier = PinnedNotifier(mockApi, storage, [_channelA, _channelB]);
    await Future<void>.delayed(Duration.zero);

    verify(mockApi.readFeed(_channelA, any)).called(1);
    verify(mockApi.readFeed(_channelB, any)).called(1);
    notifier.dispose();
  });

  test('updates entries with fetched values, sorted by channel then field id', () async {
    storage = await seededStorage([(_channelB, 2), (_channelA, 1)]);
    when(mockApi.readFeed(_channelA, any)).thenAnswer(
      (_) async => FeedData(
        fields: [
          Field(
            id: 1,
            label: 'Temp',
            values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
          ),
        ],
        statuses: [],
      ),
    );
    when(mockApi.readFeed(_channelB, any)).thenAnswer(
      (_) async => FeedData(
        fields: [
          Field(
            id: 2,
            label: 'Humidity',
            values: [FieldValue(createdAt: DateTime(2024), value: 60.0)],
          ),
        ],
        statuses: [],
      ),
    );

    final notifier = PinnedNotifier(mockApi, storage, [_channelA, _channelB]);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.entries, hasLength(2));
    expect(notifier.entries[0].channel, _channelA);
    expect(notifier.entries[0].snapshot.value, 23.5);
    expect(notifier.entries[0].snapshot.label, 'Temp');
    expect(notifier.entries[1].channel, _channelB);
    expect(notifier.entries[1].snapshot.value, 60.0);
    notifier.dispose();
  });

  test('recovers a sparse pinned field via readLastFieldEntry', () async {
    storage = await seededStorage([(_channelA, 1)]);
    when(mockApi.readFeed(any, any)).thenAnswer(
      (_) async => FeedData(fields: [const Field(id: 1, label: 'Temp')], statuses: []),
    );
    final recovered = FieldValue(createdAt: DateTime(2023), value: 42.0);
    when(
      mockApi.readLastFieldEntry(any, 1),
    ).thenAnswer((_) async => recovered);

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.entries.single.state, isA<PinnedEntryValue>());
    expect(notifier.entries.single.snapshot.value, 42.0);
    notifier.dispose();
  });

  test(
    'does not call readLastFieldEntry for fields that already have a value',
    () async {
      storage = await seededStorage([(_channelA, 1)]);
      when(mockApi.readFeed(any, any)).thenAnswer(
        (_) async => FeedData(
          fields: [
            Field(
              id: 1,
              label: 'Temp',
              values: [FieldValue(createdAt: DateTime(2024), value: 1)],
            ),
          ],
          statuses: [],
        ),
      );

      final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
      await Future<void>.delayed(Duration.zero);

      verifyNever(mockApi.readLastFieldEntry(any, any));
      notifier.dispose();
    },
  );

  test(
    'isolates a failing channel: its pins error, others stay live',
    () async {
      storage = await seededStorage([(_channelA, 1), (_channelB, 1)]);
      when(mockApi.readFeed(_channelA, any)).thenThrow(
        const ApiException(ApiErrorCode.network),
      );
      when(mockApi.readFeed(_channelB, any)).thenAnswer(
        (_) async => FeedData(
          fields: [
            Field(
              id: 1,
              label: 'Humidity',
              values: [FieldValue(createdAt: DateTime(2024), value: 60.0)],
            ),
          ],
          statuses: [],
        ),
      );

      final notifier = PinnedNotifier(mockApi, storage, [_channelA, _channelB]);
      await Future<void>.delayed(Duration.zero);

      final aEntry = notifier.entries.firstWhere((e) => e.channel == _channelA);
      final bEntry = notifier.entries.firstWhere((e) => e.channel == _channelB);
      expect(aEntry.state, isA<PinnedEntryError>());
      expect((aEntry.state as PinnedEntryError).errorCode, ApiErrorCode.network);
      expect(bEntry.state, isA<PinnedEntryValue>());
      expect(bEntry.snapshot.value, 60.0);
      notifier.dispose();
    },
  );

  test('filters out pins whose channel is not in the given list', () async {
    storage = await seededStorage([(_channelA, 1), (_channelB, 1)]);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: const [], statuses: []));

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);

    expect(notifier.entries, hasLength(1));
    expect(notifier.entries.single.channel, _channelA);
    notifier.dispose();
  });

  test('persists refreshed snapshots back to storage', () async {
    storage = await seededStorage([(_channelA, 1)]);
    when(mockApi.readFeed(any, any)).thenAnswer(
      (_) async => FeedData(
        fields: [
          Field(
            id: 1,
            label: 'Temp',
            values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
          ),
        ],
        statuses: [],
      ),
    );

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
    await Future<void>.delayed(Duration.zero);

    expect(storage.pins([_channelA]).single.value, 23.5);
    notifier.dispose();
  });

  test('setChannels re-resolves entries and refetches', () async {
    storage = await seededStorage([(_channelA, 1)]);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: const [], statuses: []));

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
    await Future<void>.delayed(Duration.zero);
    expect(notifier.entries, hasLength(1));

    notifier.setChannels([]);
    await Future<void>.delayed(Duration.zero);

    expect(notifier.entries, isEmpty);
    notifier.dispose();
  });

  test('does not call notifyListeners after dispose', () async {
    storage = await seededStorage([(_channelA, 1)]);
    when(
      mockApi.readFeed(any, any),
    ).thenAnswer((_) async => FeedData(fields: const [], statuses: []));

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
    notifier.dispose();

    await Future<void>.delayed(Duration.zero);
  });

  test('refresh is a no-op when there are no pins', () async {
    storage = await seededStorage([]);

    final notifier = PinnedNotifier(mockApi, storage, [_channelA]);
    await notifier.refresh();

    verifyNever(mockApi.readFeed(any, any));
    expect(notifier.entries, isEmpty);
    notifier.dispose();
  });
}
