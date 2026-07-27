import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/models/channel.dart';
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
      when(mockApi.readFeed(any, any)).thenAnswer((_) async => fields);

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
      when(mockApi.readFeed(any, any)).thenAnswer((_) async => emptyFields);

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
      when(mockApi.readFeed(any, any)).thenAnswer((_) async => fields);

      final notifier = ChannelDetailNotifier(mockApi, channel);
      await Future<void>.delayed(Duration.zero);

      final captured = verify(mockApi.readFeed(any, captureAny)).captured;
      final params = captured.single as ApiParameters;
      expect(params.results, 100);
      notifier.dispose();
    });

    test('does not call notifyListeners after dispose', () async {
      when(mockApi.readChannel(any)).thenAnswer((_) async => enrichedChannel);
      when(mockApi.readFeed(any, any)).thenAnswer((_) async => fields);

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
