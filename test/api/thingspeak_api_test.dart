import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:thingviewer/api/thingspeak_api.dart';
import 'package:thingviewer/models/channel.dart';

import 'thingspeak_api_test.mocks.dart';

@GenerateMocks([http.Client])
void main() {
  late MockClient mockClient;
  late ThingSpeakApi api;

  const publicChannel = Channel(
    id: 123456,
    serverUrl: 'https://api.thingspeak.com',
    isPublic: true,
  );

  setUp(() {
    mockClient = MockClient();
    api = ThingSpeakApi(mockClient);
  });

  String fixture(String name) {
    return File('test/fixtures/$name').readAsStringSync();
  }

  http.Response ok(String body) =>
      http.Response(body, 200, headers: {'content-type': 'application/json'});

  Uri feedsUriFrom(List<dynamic> captured) =>
      captured.cast<Uri>().firstWhere((uri) => uri.path.endsWith('feeds.json'));

  group('readChannel', () {
    test('parses channel name and field count', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));

      final result = await api.readChannel(publicChannel);

      expect(result.name, 'Test public channel');
      expect(result.description, 'Test channel description');
      expect(result.fieldCount, 8);
      expect(result.id, 123456);
    });

    test('parses url and githubUrl from the settings endpoint', () async {
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path.endsWith('feeds.json'))),
        ),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => !uri.path.endsWith('feeds.json'))),
        ),
      ).thenAnswer((_) async => ok(fixture('channel_settings.json')));

      final result = await api.readChannel(publicChannel);

      expect(result.url, 'https://dweet.io');
      expect(result.githubUrl, 'https://github.com/example/thingviewer-tree');
    });

    test('returns null links when the settings endpoint 404s', () async {
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => uri.path.endsWith('feeds.json'))),
        ),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      when(
        mockClient.get(
          argThat(predicate<Uri>((uri) => !uri.path.endsWith('feeds.json'))),
        ),
      ).thenAnswer((_) async => http.Response('Not Found', 404));

      final result = await api.readChannel(publicChannel);

      expect(result.name, 'Test public channel');
      expect(result.url, isNull);
      expect(result.githubUrl, isNull);
    });
  });

  group('readFeed', () {
    test('returns fields with values', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));

      final feedData = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 3),
      );

      expect(feedData.fields.length, 8);
      expect(feedData.fields.first.label, 'Field1');
      expect(feedData.fields.first.values.length, 3);
      expect(feedData.fields.first.lastValue, closeTo(10.9, 0.01));
    });

    test('returns fields with no values for empty feed', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed_empty.json')));

      final feedData = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 0),
      );

      // Channel has 8 fields defined but no feed entries
      expect(feedData.fields.length, 8);
      expect(feedData.fields.every((f) => f.values.isEmpty), isTrue);
      expect(feedData.statuses, isEmpty);
    });

    test('status=true appears in the request URI when set', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));

      await api.readFeed(publicChannel, const ApiParameters(status: true));

      final uri = verify(mockClient.get(captureAny)).captured.single as Uri;
      expect(uri.queryParameters['status'], 'true');
    });

    test('status is absent from the request URI by default', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));

      await api.readFeed(publicChannel, const ApiParameters());

      final uri = verify(mockClient.get(captureAny)).captured.single as Uri;
      expect(uri.queryParameters.containsKey('status'), isFalse);
    });

    test(
      'parses statuses, skips null/blank ones, and sorts them ascending',
      () async {
        when(
          mockClient.get(any),
        ).thenAnswer((_) async => ok(fixture('channel_feed_status.json')));

        final feedData = await api.readFeed(
          publicChannel,
          const ApiParameters(status: true),
        );

        expect(feedData.statuses.length, 2);
        expect(
          feedData.statuses[0].message,
          'BU_10:06:39: 1s 3524L (125ms) 0err recal.required',
        );
        expect(
          feedData.statuses[0].createdAt,
          DateTime.parse('2026-07-25T10:06:40Z').toLocal(),
        );
        expect(
          feedData.statuses[1].message,
          'BU_10:16:39: 1s 3525L (120ms) 0err',
        );
      },
    );

    test(
      'returns an empty status list for a channel that posts none',
      () async {
        when(
          mockClient.get(any),
        ).thenAnswer((_) async => ok(fixture('channel_feed.json')));

        final feedData = await api.readFeed(
          publicChannel,
          const ApiParameters(status: true),
        );

        expect(feedData.statuses, isEmpty);
      },
    );
  });

  group('readFeed parser hardening', () {
    String feedWithFieldValues(List<dynamic> field1Values) {
      final feeds = <Map<String, dynamic>>[];
      for (var i = 0; i < field1Values.length; i++) {
        feeds.add({
          'created_at': DateTime.utc(
            2024,
            1,
            1,
          ).add(Duration(seconds: i)).toIso8601String(),
          'field1': field1Values[i],
        });
      }
      return jsonEncode({
        'channel': {'id': 123456, 'field1': 'Field1'},
        'feeds': feeds,
      });
    }

    test(
      'drops NaN/Infinity/null values and tolerates numeric JSON values',
      () async {
        when(mockClient.get(any)).thenAnswer(
          (_) async =>
              ok(feedWithFieldValues(['NaN', null, 20, '10.5', '-Infinity'])),
        );

        final feedData = await api.readFeed(
          publicChannel,
          const ApiParameters(),
        );

        final values = feedData.fields.single.values;
        expect(values.length, 2);
        expect(values[0].value, 20.0);
        expect(values[1].value, 10.5);

        final invalidAt = feedData.fields.single.invalidAt;
        expect(invalidAt.length, 2);
        expect(invalidAt[0], DateTime.utc(2024, 1, 1).toLocal());
        expect(
          invalidAt[1],
          DateTime.utc(2024, 1, 1).add(const Duration(seconds: 4)).toLocal(),
        );
      },
    );

    test('a 100-result window keeps a field visible even though the newest '
        'entry only sets a different field (channel 851108 shape)', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed_sparse.json')));

      final feedData = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 100),
      );

      expect(feedData.fields.length, 4);
      final byId = {for (final f in feedData.fields) f.id: f};

      // field1 ("Sine"): newest entry (7) sets it to null, but its last
      // real value from entry 6 is retained rather than being dropped.
      expect(byId[1]!.lastValue, closeTo(-0.5, 0.001));
      // field2 ("Counter"): same story — last real value from entry 6.
      expect(byId[2]!.lastValue, 6.0);
      // field3 ("Sparse"): the NaN at entry 3 is skipped; newest real
      // value (entry 7) is retained.
      expect(byId[3]!.lastValue, closeTo(9.8, 0.001));
      expect(byId[3]!.values.length, 3);
      expect(byId[3]!.invalidAt, [DateTime.utc(2026, 1, 3).toLocal()]);
      // field4 ("StartOnly"): only ever set once, at the very start of the
      // range — still visible because the 100-entry window reaches back to it.
      expect(byId[4]!.lastValue, 100.0);
    });

    test('sorts values by created_at, not response order', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 'Field1'},
        'feeds': [
          {'created_at': '2024-01-02T00:00:00Z', 'field1': '2'},
          {'created_at': '2024-01-01T00:00:00Z', 'field1': '1'},
          {'created_at': '2024-01-03T00:00:00Z', 'field1': '3'},
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final feedData = await api.readFeed(publicChannel, const ApiParameters());

      final values = feedData.fields.single.values;
      expect(values.map((v) => v.value).toList(), [1.0, 2.0, 3.0]);
    });
  });

  group('malformed 200 responses', () {
    const htmlBody =
        '<!DOCTYPE html><html><body>Sign in to the network</body>'
        '</html>';

    final badBodies = <String, String>{
      'an HTML page': htmlBody,
      'truncated JSON':
          '{"channel":{"id":123456,"field1":"F1"},"feeds":[{"crea',
      'a top-level -1': '-1',
      'a top-level array': '[]',
      'an empty object': '{}',
    };

    final readers = <String, Future<Object?> Function()>{
      'readChannel': () => api.readChannel(publicChannel),
      'readFeed': () => api.readFeed(publicChannel, const ApiParameters()),
      'readField': () => api.readField(publicChannel, 1, const ApiParameters()),
      'readFieldRange': () => api.readFieldRange(
        publicChannel,
        1,
        start: DateTime.utc(2024, 1, 1),
        end: DateTime.utc(2024, 1, 2),
      ),
    };

    for (final reader in readers.entries) {
      for (final body in badBodies.entries) {
        test('${reader.key} reports invalidResponse on ${body.key}', () async {
          when(mockClient.get(any)).thenAnswer((_) async => ok(body.value));

          await expectLater(
            reader.value(),
            throwsA(
              isA<ApiException>().having(
                (e) => e.code,
                'code',
                ApiErrorCode.invalidResponse,
              ),
            ),
          );
        });
      }
    }

    test('tolerates a wrong-typed feeds container', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(
          jsonEncode({
            'channel': {'id': 123456, 'field1': 'F1'},
            'feeds': {'oops': 1},
          }),
        ),
      );

      final feedData = await api.readFeed(publicChannel, const ApiParameters());

      expect(feedData.fields.single.label, 'F1');
      expect(feedData.fields.single.values, isEmpty);
    });

    test('skips junk feed entries and keeps the good ones', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 'F1'},
        'feeds': [
          1,
          'x',
          {'created_at': '2024-01-01T00:00:00Z', 'field1': '1'},
          {'created_at': 12345, 'field1': '2'},
          {'created_at': '2024-01-03T00:00:00Z', 'field1': '3'},
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final feedData = await api.readFeed(publicChannel, const ApiParameters());

      expect(feedData.fields.single.values.map((v) => v.value).toList(), [
        1.0,
        3.0,
      ]);
    });

    test('readField skips junk entries and keeps the good ones', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 'F1'},
        'feeds': [
          1,
          {'created_at': '2024-01-01T00:00:00Z', 'field1': '1'},
          {'created_at': 12345, 'field1': '2'},
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final field = await api.readField(
        publicChannel,
        1,
        const ApiParameters(),
      );

      expect(field.values.map((v) => v.value).toList(), [1.0]);
    });

    test('reads a numeric field label as absent', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 7},
        'feeds': [
          {'created_at': '2024-01-01T00:00:00Z', 'field1': '1'},
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final feedData = await api.readFeed(publicChannel, const ApiParameters());

      expect(feedData.fields.single.label, isNull);
      expect(feedData.fields.single.values.single.value, 1.0);
    });

    test('reads a numeric status as absent', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 'F1'},
        'feeds': [
          {'created_at': '2024-01-01T00:00:00Z', 'field1': '1', 'status': 5},
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final feedData = await api.readFeed(
        publicChannel,
        const ApiParameters(status: true),
      );

      expect(feedData.statuses, isEmpty);
      expect(feedData.fields.single.values.single.value, 1.0);
    });

    test('reads wrong-typed channel metadata as absent', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'name': 7, 'updated_at': 9, 'field1': 'F1'},
        'feeds': [],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final result = await api.readChannel(publicChannel);

      expect(result.name, isNull);
      expect(result.updatedAt, isNull);
      expect(result.fieldCount, 1);
    });

    test('readLastFieldEntry stays best-effort on an HTML body', () async {
      when(mockClient.get(any)).thenAnswer((_) async => ok(htmlBody));

      expect(await api.readLastFieldEntry(publicChannel, 1), isNull);
    });

    test('a feed body that merely mentions an error still parses', () async {
      final raw = jsonEncode({
        'channel': {'id': 123456, 'field1': 'error'},
        'feeds': [
          {
            'created_at': '2024-01-01T00:00:00Z',
            'field1': '1',
            'status': 'error rate high',
          },
        ],
      });
      when(mockClient.get(any)).thenAnswer((_) async => ok(raw));

      final feedData = await api.readFeed(
        publicChannel,
        const ApiParameters(status: true),
      );

      expect(feedData.fields.single.label, 'error');
      expect(feedData.fields.single.values.single.value, 1.0);
      expect(feedData.statuses.single.message, 'error rate high');
    });
  });

  group('readFieldRange', () {
    String feedForTimes(List<DateTime> times) {
      final feeds = times
          .map(
            (t) => {
              'created_at': t.toIso8601String(),
              'field1': '${t.millisecondsSinceEpoch}',
            },
          )
          .toList();
      return jsonEncode({
        'channel': {'id': 123456, 'field1': 'Field1'},
        'feeds': feeds,
      });
    }

    String formatDate(DateTime dt) =>
        dt.toUtc().toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');

    // Like feedForTimes, but lets each entry independently carry a value (or
    // not) and an independently valid (or garbled) created_at, so the raw
    // entry timestamp and the oldest *value* timestamp can be made to diverge.
    String feedForEntries(
      List<({DateTime? createdAt, String? value})> entries,
    ) {
      final feeds = entries
          .map(
            (e) => {
              'created_at': e.createdAt?.toIso8601String() ?? 'not-a-date',
              if (e.value != null) 'field1': e.value,
            },
          )
          .toList();
      return jsonEncode({
        'channel': {'id': 123456, 'field1': 'Field1'},
        'feeds': feeds,
      });
    }

    test(
      'paginates backward past the 8000-entry cap and merges sorted results',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 12, 1);

        // Full page: exactly 8000 entries, 1 second apart, ending at `end`.
        final page1Times = List.generate(
          8000,
          (i) => end.subtract(Duration(seconds: 7999 - i)),
        );
        // Short page: continues backward from just before page 1's oldest.
        final page1Oldest = page1Times.first;
        final expectedSecondEnd = page1Oldest.subtract(
          const Duration(seconds: 1),
        );
        final page2Times = List.generate(
          100,
          (i) => expectedSecondEnd.subtract(Duration(seconds: 99 - i)),
        );

        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          return ok(feedForTimes(callCount == 1 ? page1Times : page2Times));
        });

        final result = await api.readFieldRange(
          publicChannel,
          1,
          start: start,
          end: end,
        );

        expect(callCount, 2);
        expect(result.truncated, isFalse);
        expect(result.field.values.length, 8100);
        // Sorted ascending, oldest (page 2) first.
        expect(result.field.values.first.createdAt, page2Times.first.toLocal());
        expect(result.field.values.last.createdAt, page1Times.last.toLocal());

        final captured = verify(
          mockClient.get(captureAny),
        ).captured.cast<Uri>();
        expect(captured[0].queryParameters['end'], formatDate(end));
        expect(captured[0].queryParameters['results'], '8000');
        expect(
          captured[1].queryParameters['end'],
          formatDate(expectedSecondEnd),
        );
      },
    );

    test('stops without truncation when a page comes back short', () async {
      final end = DateTime.utc(2024, 1, 10);
      final start = DateTime.utc(2024, 1, 1);
      final times = List.generate(
        50,
        (i) => end.subtract(Duration(seconds: 49 - i)),
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(feedForTimes(times)));

      final result = await api.readFieldRange(
        publicChannel,
        1,
        start: start,
        end: end,
      );

      expect(result.truncated, isFalse);
      expect(result.field.values.length, 50);
      verify(mockClient.get(any)).called(1);
    });

    test(
      'continues past a full page for a sparse field with few values '
      '(regression: must compare raw entry count, not filtered value count)',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 12, 1);

        final page1Times = List.generate(
          8000,
          (i) => end.subtract(Duration(seconds: 7999 - i)),
        );
        String page1Feed() {
          final feeds = [
            for (var i = 0; i < page1Times.length; i++)
              {
                'created_at': page1Times[i].toIso8601String(),
                if (i % 20 == 0)
                  'field1': '${page1Times[i].millisecondsSinceEpoch}',
              },
          ];
          return jsonEncode({
            'channel': {'id': 123456, 'field1': 'Field1'},
            'feeds': feeds,
          });
        }

        final page1Oldest = page1Times.first;
        final expectedSecondEnd = page1Oldest.subtract(
          const Duration(seconds: 1),
        );
        final page2Times = List.generate(
          50,
          (i) => expectedSecondEnd.subtract(Duration(seconds: 49 - i)),
        );

        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          return ok(callCount == 1 ? page1Feed() : feedForTimes(page2Times));
        });

        final result = await api.readFieldRange(
          publicChannel,
          1,
          start: start,
          end: end,
        );

        expect(callCount, 2);
        expect(result.truncated, isFalse);
        expect(result.field.values.length, 400 + 50);
      },
    );

    test(
      'returns older valid readings past a full page whose values are all '
      'null (regression: must not stop pagination on empty values)',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 12, 1);

        // Full page, every entry has a timestamp but no field1 value at all.
        final page1Times = List.generate(
          8000,
          (i) => end.subtract(Duration(seconds: 7999 - i)),
        );
        final page1 = feedForEntries([
          for (final t in page1Times) (createdAt: t, value: null),
        ]);

        final page1Oldest = page1Times.first;
        final expectedSecondEnd = page1Oldest.subtract(
          const Duration(seconds: 1),
        );
        final page2Times = List.generate(
          50,
          (i) => expectedSecondEnd.subtract(Duration(seconds: 49 - i)),
        );

        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          return ok(callCount == 1 ? page1 : feedForTimes(page2Times));
        });

        final result = await api.readFieldRange(
          publicChannel,
          1,
          start: start,
          end: end,
        );

        expect(callCount, 2);
        expect(result.truncated, isFalse);
        // Only page 2 carried usable values; page 1's readings were lost to
        // never having a parseable value, not to pagination stopping early.
        expect(result.field.values.length, 50);
        expect(
          result.field.values.first.createdAt,
          page2Times.first.toLocal(),
        );
      },
    );

    test(
      'derives the next page cursor from the oldest raw entry, not the '
      'oldest value, when the oldest entries on a page carry no value',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 12, 1);

        final page1Times = List.generate(
          8000,
          (i) => end.subtract(Duration(seconds: 7999 - i)),
        );
        // The oldest 100 raw entries have no field1 value; the rest do.
        final page1 = feedForEntries([
          for (var i = 0; i < page1Times.length; i++)
            (
              createdAt: page1Times[i],
              value: i < 100 ? null : '${page1Times[i].millisecondsSinceEpoch}',
            ),
        ]);
        final oldestValueAt = page1Times[100];
        final oldestRawAt = page1Times.first;
        // These must actually diverge, or the test proves nothing.
        expect(oldestRawAt, isNot(oldestValueAt));

        final expectedSecondEnd = oldestRawAt.subtract(
          const Duration(seconds: 1),
        );
        final page2Times = List.generate(
          50,
          (i) => expectedSecondEnd.subtract(Duration(seconds: 49 - i)),
        );

        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          return ok(callCount == 1 ? page1 : feedForTimes(page2Times));
        });

        await api.readFieldRange(publicChannel, 1, start: start, end: end);

        final captured = verify(
          mockClient.get(captureAny),
        ).captured.cast<Uri>();
        expect(
          captured[1].queryParameters['end'],
          formatDate(expectedSecondEnd),
        );
      },
    );

    test(
      'collects invalidAt markers from an all-invalid page and continues '
      'pagination past it',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 11, 1);

        // Newest page: a full page of valid readings.
        final page1Times = List.generate(
          8000,
          (i) => end.subtract(Duration(seconds: 7999 - i)),
        );
        final page1 = feedForTimes(page1Times);

        // Middle page: a full page whose every value is non-finite.
        final page1Oldest = page1Times.first;
        final page2End = page1Oldest.subtract(const Duration(seconds: 1));
        final page2Times = List.generate(
          8000,
          (i) => page2End.subtract(Duration(seconds: 7999 - i)),
        );
        final page2 = feedForEntries([
          for (final t in page2Times) (createdAt: t, value: 'NaN'),
        ]);

        // Oldest page: a short page of valid readings, terminating pagination.
        final page2Oldest = page2Times.first;
        final page3End = page2Oldest.subtract(const Duration(seconds: 1));
        final page3Times = List.generate(
          50,
          (i) => page3End.subtract(Duration(seconds: 49 - i)),
        );
        final page3 = feedForTimes(page3Times);

        var callCount = 0;
        when(mockClient.get(any)).thenAnswer((_) async {
          callCount++;
          return ok(switch (callCount) {
            1 => page1,
            2 => page2,
            _ => page3,
          });
        });

        final result = await api.readFieldRange(
          publicChannel,
          1,
          start: start,
          end: end,
        );

        expect(callCount, 3);
        expect(result.truncated, isFalse);
        expect(result.field.values.length, 8000 + 50);
        expect(result.field.invalidAt.length, 8000);
        expect(
          result.field.invalidAt.toSet(),
          page2Times.map((t) => t.toLocal()).toSet(),
        );
      },
    );

    test(
      'stops and reports truncated when a full page has no parseable '
      'created_at anywhere on it',
      () async {
        final end = DateTime.utc(2024, 1, 10);
        final start = DateTime.utc(2023, 12, 1);

        final page = feedForEntries([
          for (var i = 0; i < 8000; i++) (createdAt: null, value: '1.0'),
        ]);

        when(mockClient.get(any)).thenAnswer((_) async => ok(page));

        final result = await api.readFieldRange(
          publicChannel,
          1,
          start: start,
          end: end,
        );

        expect(result.truncated, isTrue);
        expect(result.field.values, isEmpty);
        verify(mockClient.get(any)).called(1);
      },
    );
  });

  group('readLastFieldEntry', () {
    test('parses the value and timestamp from a bare entry object', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('fields_last.json')));

      final result = await api.readLastFieldEntry(publicChannel, 1);

      expect(result, isNotNull);
      expect(result!.value, 3646.0);
      expect(result.createdAt, DateTime.parse('2026-07-20T08:15:30Z').toLocal());
    });

    test('returns null on a 404 with body -1 (field never written)', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => http.Response('-1', 404));

      final result = await api.readLastFieldEntry(publicChannel, 3);

      expect(result, isNull);
    });

    test('returns null when the field value is non-numeric', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(
          jsonEncode({'created_at': '2026-07-20T08:15:30Z', 'field1': 'oops'}),
        ),
      );

      final result = await api.readLastFieldEntry(publicChannel, 1);

      expect(result, isNull);
    });

    test('returns null when the field value is non-finite', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(
          jsonEncode({'created_at': '2026-07-20T08:15:30Z', 'field1': 'NaN'}),
        ),
      );

      final result = await api.readLastFieldEntry(publicChannel, 1);

      expect(result, isNull);
    });

    test('includes api_key in the request URI', () async {
      const privateChannel = Channel(
        id: 42,
        serverUrl: 'https://api.thingspeak.com',
        isPublic: false,
        apiKey: 'SECRET123',
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('fields_last.json')));

      await api.readLastFieldEntry(privateChannel, 1);

      final uri = verify(mockClient.get(captureAny)).captured.single as Uri;
      expect(uri.path, '/channels/42/fields/1/last.json');
      expect(uri.queryParameters['api_key'], 'SECRET123');
    });
  });

  group('_buildUri', () {
    test('defaults to https://api.thingspeak.com', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      await api.readChannel(publicChannel);

      final uri = feedsUriFrom(verify(mockClient.get(captureAny)).captured);
      expect(uri.scheme, 'https');
      expect(uri.host, 'api.thingspeak.com');
      expect(uri.path, '/channels/123456/feeds.json');
    });

    test('preserves an explicit port on a custom server', () async {
      const channel = Channel(
        id: 42,
        serverUrl: 'http://192.168.1.5:8080',
        isPublic: true,
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      await api.readChannel(channel);

      final uri = feedsUriFrom(verify(mockClient.get(captureAny)).captured);
      expect(uri.host, '192.168.1.5');
      expect(uri.port, 8080);
      expect(uri.path, '/channels/42/feeds.json');
    });

    test('joins a custom server base path', () async {
      const channel = Channel(
        id: 42,
        serverUrl: 'http://192.168.1.5:8080/thingspeak',
        isPublic: true,
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      await api.readChannel(channel);

      final uri = feedsUriFrom(verify(mockClient.get(captureAny)).captured);
      expect(uri.host, '192.168.1.5');
      expect(uri.port, 8080);
      expect(uri.path, '/thingspeak/channels/42/feeds.json');
    });

    test('handles a trailing slash on the base URL', () async {
      const channel = Channel(
        id: 42,
        serverUrl: 'http://192.168.1.5:8080/thingspeak/',
        isPublic: true,
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      await api.readChannel(channel);

      final uri = feedsUriFrom(verify(mockClient.get(captureAny)).captured);
      expect(uri.path, '/thingspeak/channels/42/feeds.json');
    });

    test('does not leak a query string from the base URL', () async {
      const channel = Channel(
        id: 42,
        serverUrl: 'http://192.168.1.5:8080?foo=bar',
        isPublic: true,
      );
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed.json')));
      await api.readChannel(channel);

      final uri = feedsUriFrom(verify(mockClient.get(captureAny)).captured);
      expect(uri.queryParameters.containsKey('foo'), isFalse);
    });
  });

  group('error handling', () {
    test(
      'throws ApiException with credentials code on auth error (400 -1)',
      () async {
        when(
          mockClient.get(any),
        ).thenAnswer((_) async => http.Response('-1', 400));

        expect(
          () => api.readChannel(publicChannel),
          throwsA(
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.credentials,
            ),
          ),
        );
      },
    );

    test('throws credentials on a 200 JSON auth error body', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('error_auth_response.json')));

      // ThingSpeak returns its auth error object under a 200 status, so the
      // status alone cannot be trusted.
      await expectLater(
        api.readChannel(publicChannel),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', ApiErrorCode.credentials)
              .having(
                (e) => e.serverMessage,
                'serverMessage',
                'Please make sure that your API key is correct.',
              ),
        ),
      );
    });

    test('throws ApiException with network code on SocketException', () {
      when(
        mockClient.get(any),
      ).thenThrow(const SocketException('No address', osError: OSError('', 7)));

      expect(
        () => api.readChannel(publicChannel),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            ApiErrorCode.network,
          ),
        ),
      );
    });

    test(
      'throws ApiException with network code when the request stalls past the timeout',
      () {
        fakeAsync((async) {
          when(
            mockClient.get(any),
          ).thenAnswer((_) => Completer<http.Response>().future);

          Object? caught;
          api.readChannel(publicChannel).catchError((e) {
            caught = e;
            return publicChannel;
          });

          async.elapse(const Duration(seconds: 21));

          expect(
            caught,
            isA<ApiException>().having(
              (e) => e.code,
              'code',
              ApiErrorCode.network,
            ),
          );
        });
      },
    );
  });
}
