import 'dart:io';

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

  group('readChannel', () {
    test('parses channel name and field count', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(fixture('channel_feed.json')),
      );

      final result = await api.readChannel(publicChannel);

      expect(result.name, 'Test public channel');
      expect(result.fieldCount, 8);
      expect(result.id, 123456);
    });
  });

  group('readFeed', () {
    test('returns fields with values', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(fixture('channel_feed.json')),
      );

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
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(fixture('channel_feed_empty.json')),
      );

      final fields = await api.readFeed(
        publicChannel,
        const ApiParameters(results: 0),
      );

      // Channel has 8 fields defined but no feed entries
      expect(fields.length, 8);
      expect(fields.every((f) => f.values.isEmpty), isTrue);
    });
  });

  group('error handling', () {
    test('throws ApiException with credentials code on auth error (400 -1)',
        () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => http.Response('-1', 400),
      );

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
    });

    test('parses normally on 200 JSON error body', () async {
      when(mockClient.get(any)).thenAnswer(
        (_) async => ok(fixture('error_auth_response.json')),
      );

      // ThingSpeak sometimes returns 200 with an error JSON body.
      // The client should not throw — it returns the channel with no enrichment.
      final result = await api.readChannel(publicChannel);
      expect(result.id, publicChannel.id);
      expect(result.name, isNull);
    });

    test('throws ApiException with network code on SocketException', () {
      when(mockClient.get(any)).thenThrow(
        const SocketException('No address', osError: OSError('', 7)),
      );

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
  });
}
