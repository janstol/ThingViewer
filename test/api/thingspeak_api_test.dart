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

      final fields = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 3),
      );

      expect(fields.length, 8);
      expect(fields.first.label, 'Field1');
      expect(fields.first.values.length, 3);
      expect(fields.first.lastValue, closeTo(10.9, 0.01));
    });

    test('returns fields with no values for empty feed', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('channel_feed_empty.json')));

      final fields = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 0),
      );

      // Channel has 8 fields defined but no feed entries
      expect(fields.length, 8);
      expect(fields.every((f) => f.values.isEmpty), isTrue);
    });
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

        final fields = await api.readFeed(publicChannel, const ApiParameters());

        final values = fields.single.values;
        expect(values.length, 2);
        expect(values[0].value, 20.0);
        expect(values[1].value, 10.5);

        final invalidAt = fields.single.invalidAt;
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

      final fields = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 100),
      );

      expect(fields.length, 4);
      final byId = {for (final f in fields) f.id: f};

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

      final fields = await api.readFeed(publicChannel, const ApiParameters());

      final values = fields.single.values;
      expect(values.map((v) => v.value).toList(), [1.0, 2.0, 3.0]);
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

    test('parses normally on 200 JSON error body', () async {
      when(
        mockClient.get(any),
      ).thenAnswer((_) async => ok(fixture('error_auth_response.json')));

      // ThingSpeak sometimes returns 200 with an error JSON body.
      // The client should not throw — it returns the channel with no enrichment.
      final result = await api.readChannel(publicChannel);
      expect(result.id, publicChannel.id);
      expect(result.name, isNull);
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
