import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/models/channel.dart';
import 'package:thingviewer/models/field.dart';
import 'package:thingviewer/screens/field_chart/field_chart_notifier.dart';

import 'field_chart_notifier_test.mocks.dart';

@GenerateMocks([ThingSpeakApi])
void main() {
  late MockThingSpeakApi mockApi;

  const channel = Channel(
    id: 1,
    serverUrl: 'https://api.thingspeak.com',
    isPublic: true,
  );

  final now = DateTime(2024, 1, 15, 12, 0);
  final yesterday = DateTime(2024, 1, 14, 12, 0);
  final twoDaysAgo = DateTime(2024, 1, 13, 12, 0);

  setUp(() {
    mockApi = MockThingSpeakApi();
    // Default stub for the constructor-time auto-fetch. Returns an empty field
    // so the fixture cache is not clobbered. Tests that need specific return
    // values override this stub after calling settleNotifier().
    when(mockApi.readField(any, any, any))
        .thenAnswer((_) async => const Field(id: 1, label: 'Temp'));
  });

  Field fieldWithValues(List<DateTime> times) => Field(
        id: 1,
        label: 'Temp',
        values: times
            .map((t) => FieldValue(createdAt: t, value: 42.0))
            .toList(),
      );

  /// Constructs a [FieldChartNotifier], waits for the constructor-time
  /// auto-fetch to complete, then clears mock interaction counts so that
  /// per-test [verify] / [verifyNever] calls start from a clean slate.
  Future<FieldChartNotifier> settleNotifier(Field field) async {
    final n = FieldChartNotifier(mockApi, channel, field);
    await pumpEventQueue();
    clearInteractions(mockApi);
    return n;
  }

  group('initial state', () {
    // The constructor immediately kicks off an async auto-fetch, so the
    // synchronous state is always FieldChartLoading. These tests verify the
    // settled state after the first fetch completes.

    test('is FieldChartLoaded after auto-fetch returns values', () async {
      // Use DateTime.now()-relative dates so they fall within the default 7-day range.
      final recentValues = [
        DateTime.now().subtract(const Duration(days: 2)),
        DateTime.now().subtract(const Duration(days: 1)),
      ];
      when(mockApi.readField(any, any, any))
          .thenAnswer((_) async => fieldWithValues(recentValues));

      final notifier = FieldChartNotifier(
        mockApi,
        channel,
        const Field(id: 1, label: 'Temp'),
      );
      await pumpEventQueue();

      expect(notifier.state, isA<FieldChartLoaded>());
      final loaded = notifier.state as FieldChartLoaded;
      expect(loaded.values.length, 2);
      notifier.dispose();
    });

    test('is FieldChartEmpty after auto-fetch returns no values', () async {
      // Default stub returns an empty Field.
      final notifier = FieldChartNotifier(
        mockApi,
        channel,
        const Field(id: 1, label: 'Temp'),
      );
      await pumpEventQueue();

      expect(notifier.state, isA<FieldChartEmpty>());
      notifier.dispose();
    });
  });

  group('applyFilter', () {
    test('uses cache when range is already covered', () async {
      final field = fieldWithValues([twoDaysAgo, yesterday, now]);
      final notifier = await settleNotifier(field);

      // Filter to just yesterday–now — should NOT fetch (cache covers the range).
      await notifier.applyFilter(DateTimeRange(start: yesterday, end: now));

      verifyNever(mockApi.readField(any, any, any));
      expect(notifier.state, isA<FieldChartLoaded>());
      final loaded = notifier.state as FieldChartLoaded;
      expect(loaded.values.length, 2); // yesterday + now
      notifier.dispose();
    });

    test('fetches from API when range extends beyond cache', () async {
      final field = fieldWithValues([yesterday, now]);
      final notifier = await settleNotifier(field);

      final extendedStart = DateTime(2024, 1, 10);
      final fetchedField = fieldWithValues([extendedStart, yesterday, now]);
      when(mockApi.readField(any, 1, any)).thenAnswer((_) async => fetchedField);

      await notifier.applyFilter(
        DateTimeRange(start: extendedStart, end: now),
      );

      verify(mockApi.readField(any, 1, any)).called(1);
      expect(notifier.state, isA<FieldChartLoaded>());
      notifier.dispose();
    });

    test('returns FieldChartError with cached values on API failure', () async {
      final field = fieldWithValues([yesterday, now]);
      final notifier = await settleNotifier(field);

      final extendedStart = DateTime(2024, 1, 10);
      when(mockApi.readField(any, 1, any)).thenThrow(
        const ApiException(ApiErrorCode.network),
      );

      await notifier.applyFilter(
        DateTimeRange(start: extendedStart, end: now),
      );

      expect(notifier.state, isA<FieldChartError>());
      final error = notifier.state as FieldChartError;
      expect(error.errorCode, ApiErrorCode.network);
      notifier.dispose();
    });

    test('returns FieldChartEmpty when no data in range', () async {
      final field = fieldWithValues([yesterday, now]);
      final notifier = await settleNotifier(field);

      final farFuture = DateTime(2030);
      when(mockApi.readField(any, 1, any))
          .thenAnswer((_) async => const Field(id: 1, label: 'Temp'));

      await notifier.applyFilter(
        DateTimeRange(
          start: farFuture,
          end: farFuture.add(const Duration(hours: 1)),
        ),
      );

      expect(notifier.state, isA<FieldChartEmpty>());
      notifier.dispose();
    });
  });
}
