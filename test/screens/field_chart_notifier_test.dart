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

  // Matches any call to readFieldRange regardless of arguments — factored out
  // since mockito requires a matcher for every named parameter the real call
  // site passes (apiKey, start, end), and repeating that is noisy.
  Future<FieldRange> anyReadFieldRange() => mockApi.readFieldRange(
    any,
    any,
    apiKey: anyNamed('apiKey'),
    start: anyNamed('start'),
    end: anyNamed('end'),
  );

  setUp(() {
    mockApi = MockThingSpeakApi();
    // Default stub for the constructor-time auto-fetch. Returns an empty field
    // so the fixture cache is not clobbered. Tests that need specific return
    // values override this stub after calling settleNotifier().
    when(
      anyReadFieldRange(),
    ).thenAnswer((_) async => const FieldRange(field: Field(id: 1), truncated: false));
  });

  Field fieldWithValues(List<DateTime> times) => Field(
    id: 1,
    label: 'Temp',
    values: times.map((t) => FieldValue(createdAt: t, value: 42.0)).toList(),
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
      when(anyReadFieldRange()).thenAnswer(
        (_) async =>
            FieldRange(field: fieldWithValues(recentValues), truncated: false),
      );

      final notifier = FieldChartNotifier(
        mockApi,
        channel,
        const Field(id: 1, label: 'Temp'),
      );
      await pumpEventQueue();

      expect(notifier.state, isA<FieldChartLoaded>());
      final loaded = notifier.state as FieldChartLoaded;
      expect(loaded.values.length, 2);
      expect(loaded.truncated, isFalse);
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

    test('surfaces truncated: true from the API on the loaded state', () async {
      final recentValues = [
        DateTime.now().subtract(const Duration(days: 2)),
        DateTime.now().subtract(const Duration(days: 1)),
      ];
      when(anyReadFieldRange()).thenAnswer(
        (_) async =>
            FieldRange(field: fieldWithValues(recentValues), truncated: true),
      );

      final notifier = FieldChartNotifier(
        mockApi,
        channel,
        const Field(id: 1, label: 'Temp'),
      );
      await pumpEventQueue();

      final loaded = notifier.state as FieldChartLoaded;
      expect(loaded.truncated, isTrue);
      notifier.dispose();
    });

    test(
      'anchors the default range on a stale field\'s last value, not now',
      () async {
        final lastUpdated = DateTime(2025, 11, 4);
        final notifier = FieldChartNotifier(
          mockApi,
          channel,
          fieldWithValues([lastUpdated]),
        );
        await pumpEventQueue();

        final captured = verify(
          mockApi.readFieldRange(
            any,
            any,
            apiKey: anyNamed('apiKey'),
            start: captureAnyNamed('start'),
            end: captureAnyNamed('end'),
          ),
        ).captured;
        final requestedStart = captured[0] as DateTime;
        final requestedEnd = captured[1] as DateTime;

        expect(requestedEnd, lastUpdated);
        expect(requestedStart, lastUpdated.subtract(const Duration(days: 7)));
        notifier.dispose();
      },
    );
  });

  group('applyFilter', () {
    test('uses cache when range is already covered', () async {
      final notifier = await settleNotifier(const Field(id: 1, label: 'Temp'));

      // First fetch: populates cache and records this exact range as covered.
      when(anyReadFieldRange()).thenAnswer(
        (_) async => FieldRange(
          field: fieldWithValues([twoDaysAgo, yesterday, now]),
          truncated: false,
        ),
      );
      await notifier.applyFilter(DateTimeRange(start: twoDaysAgo, end: now));
      clearInteractions(mockApi);

      // Filter to just yesterday–now, a sub-range of what's covered above —
      // should NOT fetch.
      await notifier.applyFilter(DateTimeRange(start: yesterday, end: now));

      verifyNever(anyReadFieldRange());
      expect(notifier.state, isA<FieldChartLoaded>());
      final loaded = notifier.state as FieldChartLoaded;
      expect(loaded.values.length, 2); // yesterday + now
      notifier.dispose();
    });

    test('fetches from API when range extends beyond cache', () async {
      final notifier = await settleNotifier(const Field(id: 1, label: 'Temp'));

      when(anyReadFieldRange()).thenAnswer(
        (_) async => FieldRange(
          field: fieldWithValues([yesterday, now]),
          truncated: false,
        ),
      );
      await notifier.applyFilter(DateTimeRange(start: yesterday, end: now));
      clearInteractions(mockApi);

      final extendedStart = DateTime(2024, 1, 10);
      when(anyReadFieldRange()).thenAnswer(
        (_) async => FieldRange(
          field: fieldWithValues([extendedStart, yesterday, now]),
          truncated: false,
        ),
      );

      await notifier.applyFilter(DateTimeRange(start: extendedStart, end: now));

      verify(anyReadFieldRange()).called(1);
      expect(notifier.state, isA<FieldChartLoaded>());
      notifier.dispose();
    });

    test(
      'fetches again when the requested range falls in the hole between '
      'two previously fetched, disjoint ranges',
      () async {
        final notifier = await settleNotifier(
          const Field(id: 1, label: 'Temp'),
        );

        final rangeA = DateTimeRange(
          start: DateTime(2024, 1, 10),
          end: DateTime(2024, 1, 12),
        );
        final rangeB = DateTimeRange(
          start: DateTime(2024, 1, 1),
          end: DateTime(2024, 1, 3),
        );
        // Falls between rangeB and rangeA — never fetched, but its bounds
        // sit within the overall min/max of already-cached data, which is
        // exactly what the old cache-coverage heuristic got wrong.
        final holeRange = DateTimeRange(
          start: DateTime(2024, 1, 5),
          end: DateTime(2024, 1, 7),
        );

        when(anyReadFieldRange()).thenAnswer(
          (_) async => FieldRange(
            field: fieldWithValues([rangeA.start]),
            truncated: false,
          ),
        );
        await notifier.applyFilter(rangeA);

        when(anyReadFieldRange()).thenAnswer(
          (_) async => FieldRange(
            field: fieldWithValues([rangeB.start]),
            truncated: false,
          ),
        );
        await notifier.applyFilter(rangeB);

        clearInteractions(mockApi);
        when(anyReadFieldRange()).thenAnswer(
          (_) async => FieldRange(
            field: fieldWithValues([holeRange.start]),
            truncated: false,
          ),
        );

        await notifier.applyFilter(holeRange);

        verify(anyReadFieldRange()).called(1);
        expect(notifier.state, isA<FieldChartLoaded>());
        notifier.dispose();
      },
    );

    test('returns FieldChartError with cached values on API failure', () async {
      final notifier = await settleNotifier(const Field(id: 1, label: 'Temp'));

      when(anyReadFieldRange()).thenAnswer(
        (_) async => FieldRange(
          field: fieldWithValues([yesterday, now]),
          truncated: false,
        ),
      );
      await notifier.applyFilter(DateTimeRange(start: yesterday, end: now));

      final extendedStart = DateTime(2024, 1, 10);
      when(
        anyReadFieldRange(),
      ).thenThrow(const ApiException(ApiErrorCode.network));

      await notifier.applyFilter(DateTimeRange(start: extendedStart, end: now));

      expect(notifier.state, isA<FieldChartError>());
      final error = notifier.state as FieldChartError;
      expect(error.errorCode, ApiErrorCode.network);
      notifier.dispose();
    });

    test('returns FieldChartEmpty when no data in range', () async {
      final notifier = await settleNotifier(const Field(id: 1, label: 'Temp'));

      final farFuture = DateTime(2030);
      when(
        anyReadFieldRange(),
      ).thenAnswer((_) async => const FieldRange(field: Field(id: 1, label: 'Temp'), truncated: false));

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
