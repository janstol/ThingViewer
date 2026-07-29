import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/channel_status.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/screens/channel_detail/channel_detail_notifier.dart';

import 'channel_detail_notifier_test.mocks.dart';

@GenerateMocks([ThingSpeakApi])
void main() {
  late MockThingSpeakApi mockApi;

  const channel = Channel(
    id: 1,
    serverUrl: 'https://api.thingspeak.com',
    isPublic: true,
  );

  final enrichedChannel = channel.copyWith(name: 'My Channel', fieldCount: 2);

  final fields = [
    Field(
      id: 1,
      label: 'Temp',
      values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
    ),
    Field(
      id: 2,
      label: 'Humidity',
      values: [FieldValue(createdAt: DateTime(2024), value: 60.0)],
    ),
  ];

  setUp(() {
    mockApi = MockThingSpeakApi();
  });

  group('load', () {
    test('is ChannelDetailLoaded on success', () async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: fields, statuses: []));

      final notifier = ChannelDetailNotifier(mockApi, channel);
      // Constructor calls load(); wait for it to settle.
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<ChannelDetailLoaded>());
      final loaded = notifier.state as ChannelDetailLoaded;
      expect(loaded.channel.name, 'My Channel');
      expect(loaded.fields.length, 2);
      notifier.dispose();
    });

    test('is ChannelDetailEmpty when all fields have no values', () async {
      final emptyFields = [
        const Field(id: 1, label: 'Temp'),
        const Field(id: 2, label: 'Humidity'),
      ];
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: emptyFields, statuses: []));
      when(
        mockApi.readLastFieldEntry(any, any),
      ).thenAnswer((_) async => null);

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<ChannelDetailEmpty>());
      notifier.dispose();
    });

    test('is ChannelDetailError when readChannel fails', () async {
      when(
        mockApi.readChannel(any),
      ).thenThrow(const ApiException(ApiErrorCode.network));

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      expect(notifier.state, isA<ChannelDetailError>());
      final error = notifier.state as ChannelDetailError;
      expect(error.errorCode, ApiErrorCode.network);
      notifier.dispose();
    });

    test(
      'is ChannelDetailError when readFeed fails after readChannel succeeds',
      () async {
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenThrow(const ApiException(ApiErrorCode.credentials));

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state, isA<ChannelDetailError>());
        final error = notifier.state as ChannelDetailError;
        expect(error.errorCode, ApiErrorCode.credentials);
        // Channel reference should be the original (not enriched), since
        // _channel = updated only runs after readFeed succeeds.
        expect(error.channel.name, isNull);
        notifier.dispose();
      },
    );

    test('requests 100 results, not just the latest entry, so a field with no '
        'value in the newest entry is not dropped', () async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: fields, statuses: []));

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      final captured = verify(mockApi.readFeed(any, captureAny)).captured;
      final params = captured.single as ApiParameters;
      expect(params.results, 100);
      expect(params.status, true);
      notifier.dispose();
    });

    test('carries statuses through to ChannelDetailLoaded', () async {
      final statuses = [
        ChannelStatus(createdAt: DateTime(2024), message: 'BU_10:06:39'),
      ];
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: fields, statuses: statuses));

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      final loaded = notifier.state as ChannelDetailLoaded;
      expect(loaded.statuses, statuses);
      notifier.dispose();
    });

    test('carries statuses through to ChannelDetailEmpty', () async {
      final statuses = [
        ChannelStatus(createdAt: DateTime(2024), message: 'BU_10:06:39'),
      ];
      final emptyFields = [const Field(id: 1, label: 'Temp')];
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(mockApi.readFeed(any, any)).thenAnswer(
        (_) async => FeedData(fields: emptyFields, statuses: statuses),
      );
      when(
        mockApi.readLastFieldEntry(any, any),
      ).thenAnswer((_) async => null);

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      final empty = notifier.state as ChannelDetailEmpty;
      expect(empty.statuses, statuses);
      notifier.dispose();
    });

    test(
      'reports authError: true through onChannelUpdated on a credentials failure',
      () async {
        when(
          mockApi.readChannel(any),
        ).thenThrow(const ApiException(ApiErrorCode.credentials));
        Channel? reported;

        final notifier = ChannelDetailNotifier(
          mockApi,
          channel,
          onChannelUpdated: (c) => reported = c,
        );
        await Future<void>.delayed(Duration.zero);

        expect(reported?.authError, isTrue);
        final error = notifier.state as ChannelDetailError;
        expect(error.channel.authError, isTrue);
        notifier.dispose();
      },
    );

    test(
      'reports authError: false through onChannelUpdated once a load succeeds',
      () async {
        when(
          mockApi.readChannel(any),
        ).thenThrow(const ApiException(ApiErrorCode.credentials));
        Channel? reported;

        final notifier = ChannelDetailNotifier(
          mockApi,
          channel,
          onChannelUpdated: (c) => reported = c,
        );
        await Future<void>.delayed(Duration.zero);
        expect(reported?.authError, isTrue);

        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: fields, statuses: []));
        await notifier.load();

        expect(reported?.authError, isFalse);
        notifier.dispose();
      },
    );

    test(
      'does not call readLastFieldEntry when no field is empty',
      () async {
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: fields, statuses: []));

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        verifyNever(mockApi.readLastFieldEntry(any, any));
        notifier.dispose();
      },
    );

    test(
      'recovers a sparse field via readLastFieldEntry and keeps id order',
      () async {
        final sparseFields = [
          Field(
            id: 1,
            label: 'Temp',
            values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
          ),
          const Field(id: 2, label: 'Humidity'),
        ];
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: sparseFields, statuses: []));
        final recovered = FieldValue(createdAt: DateTime(2023), value: 60.0);
        when(
          mockApi.readLastFieldEntry(any, 2),
        ).thenAnswer((_) async => recovered);

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state, isA<ChannelDetailLoaded>());
        final loaded = notifier.state as ChannelDetailLoaded;
        expect(loaded.fields.map((f) => f.id).toList(), [1, 2]);
        expect(loaded.fields[1].lastValue, 60.0);
        expect(loaded.fields[1].label, 'Humidity');
        notifier.dispose();
      },
    );

    test(
      'a field whose readLastFieldEntry returns null stays filtered out',
      () async {
        final sparseFields = [
          Field(
            id: 1,
            label: 'Temp',
            values: [FieldValue(createdAt: DateTime(2024), value: 23.5)],
          ),
          const Field(id: 2, label: 'Humidity'),
        ];
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: sparseFields, statuses: []));
        when(
          mockApi.readLastFieldEntry(any, 2),
        ).thenAnswer((_) async => null);

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state, isA<ChannelDetailLoaded>());
        final loaded = notifier.state as ChannelDetailLoaded;
        expect(loaded.fields.map((f) => f.id).toList(), [1]);
        notifier.dispose();
      },
    );

    test(
      'an all-sparse channel that recovers at least one value yields Loaded',
      () async {
        final emptyFields = [
          const Field(id: 1, label: 'Temp'),
          const Field(id: 2, label: 'Humidity'),
        ];
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: emptyFields, statuses: []));
        when(mockApi.readLastFieldEntry(any, 1)).thenAnswer((_) async => null);
        when(mockApi.readLastFieldEntry(any, 2)).thenAnswer(
          (_) async => FieldValue(createdAt: DateTime(2023), value: 5.0),
        );

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state, isA<ChannelDetailLoaded>());
        final loaded = notifier.state as ChannelDetailLoaded;
        expect(loaded.fields.map((f) => f.id).toList(), [2]);
        notifier.dispose();
      },
    );

    test(
      'an all-sparse-and-unrecoverable channel still yields Empty',
      () async {
        final emptyFields = [
          const Field(id: 1, label: 'Temp'),
          const Field(id: 2, label: 'Humidity'),
        ];
        when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
        when(
          mockApi.readFeed(any, any),
        ).thenAnswer((_) async => FeedData(fields: emptyFields, statuses: []));
        when(
          mockApi.readLastFieldEntry(any, any),
        ).thenAnswer((_) async => null);

        final notifier = ChannelDetailNotifier(mockApi, channel);
        await Future<void>.delayed(Duration.zero);

        expect(notifier.state, isA<ChannelDetailEmpty>());
        notifier.dispose();
      },
    );

    test('does not call notifyListeners after dispose', () async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(
        mockApi.readFeed(any, any),
      ).thenAnswer((_) async => FeedData(fields: fields, statuses: []));

      final notifier = ChannelDetailNotifier(mockApi, channel);
      // Dispose before the async load completes.
      notifier.dispose();

      // If notifyListeners() is incorrectly called on a disposed notifier,
      // Flutter throws in debug mode. Awaiting here would surface that.
      await Future<void>.delayed(Duration.zero);
      // Reaching here without exception means the guard works.
    });
  });
}
