import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/models/channel_snapshot.dart';
import 'package:thingviewer/models/channel_status.dart';

void main() {
  group('FieldSnapshot', () {
    test('round trips a fully populated snapshot', () {
      final field = FieldSnapshot(
        id: 1,
        label: 'Temperature',
        value: 21.5,
        valueAt: DateTime.utc(2024, 3, 1, 12),
      );

      final decoded = FieldSnapshot.fromJson(field.toJson());

      expect(decoded, field);
    });

    test('round trips with null label/value/valueAt', () {
      const field = FieldSnapshot(id: 1);

      final decoded = FieldSnapshot.fromJson(field.toJson());

      expect(decoded, field);
    });

    test('parses an integer value as a double', () {
      final decoded = FieldSnapshot.fromJson({'id': 1, 'value': 5});

      expect(decoded.value, 5.0);
    });

    group('mergedWith', () {
      test('a null new value keeps the older value and valueAt', () {
        final older = FieldSnapshot(
          id: 1,
          label: 'Temperature',
          value: 20,
          valueAt: DateTime.utc(2024, 1, 1),
        );
        const newer = FieldSnapshot(id: 1, label: 'Temperature');

        final merged = newer.mergedWith(older);

        expect(merged.value, older.value);
        expect(merged.valueAt, older.valueAt);
      });

      test('a non-null new value replaces the older value and valueAt', () {
        final older = FieldSnapshot(
          id: 1,
          value: 20,
          valueAt: DateTime.utc(2024, 1, 1),
        );
        final newer = FieldSnapshot(
          id: 1,
          value: 21,
          valueAt: DateTime.utc(2024, 1, 2),
        );

        final merged = newer.mergedWith(older);

        expect(merged.value, 21);
        expect(merged.valueAt, DateTime.utc(2024, 1, 2));
      });

      test('a null new label keeps the older label', () {
        const older = FieldSnapshot(id: 1, label: 'Temperature');
        const newer = FieldSnapshot(id: 1);

        final merged = newer.mergedWith(older);

        expect(merged.label, 'Temperature');
      });
    });
  });

  group('ChannelSnapshot', () {
    test('round trips a fully populated snapshot', () {
      final snapshot = ChannelSnapshot(
        description: 'A channel',
        url: 'https://dweet.io',
        githubUrl: 'https://github.com/example/repo',
        fields: [FieldSnapshot(id: 1, label: 'Temp', value: 21.5)],
        statuses: [
          ChannelStatus(createdAt: DateTime.utc(2024, 1, 1), message: 'ok'),
        ],
        fetchedAt: DateTime.utc(2024, 1, 2),
      );

      final decoded = ChannelSnapshot.fromJson(snapshot.toJson());

      expect(decoded.description, snapshot.description);
      expect(decoded.url, snapshot.url);
      expect(decoded.githubUrl, snapshot.githubUrl);
      expect(decoded.fields, snapshot.fields);
      expect(decoded.statuses.single.message, 'ok');
      expect(decoded.fetchedAt, snapshot.fetchedAt);
    });

    test('round trips with null metadata and empty fields/statuses', () {
      final snapshot = ChannelSnapshot(fetchedAt: DateTime.utc(2024));

      final decoded = ChannelSnapshot.fromJson(snapshot.toJson());

      expect(decoded.description, isNull);
      expect(decoded.url, isNull);
      expect(decoded.githubUrl, isNull);
      expect(decoded.fields, isEmpty);
      expect(decoded.statuses, isEmpty);
      expect(decoded.fetchedAt, snapshot.fetchedAt);
    });

    test('caps statuses at 50 on write, keeping the most recent', () {
      final statuses = List.generate(
        60,
        (i) => ChannelStatus(
          createdAt: DateTime.utc(2024, 1, 1).add(Duration(minutes: i)),
          message: 'status $i',
        ),
      );

      final snapshot = ChannelSnapshot(
        statuses: statuses,
        fetchedAt: DateTime.utc(2024),
      );

      expect(snapshot.statuses, hasLength(50));
      expect(snapshot.statuses.first.message, 'status 10');
      expect(snapshot.statuses.last.message, 'status 59');
    });

    group('mergedWith', () {
      test('null metadata falls back to the older snapshot', () {
        final older = ChannelSnapshot(
          description: 'Old description',
          url: 'https://old.example.com',
          githubUrl: 'https://github.com/example/old',
          fetchedAt: DateTime.utc(2024, 1, 1),
        );
        final newer = ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 2));

        final merged = newer.mergedWith(older);

        expect(merged.description, older.description);
        expect(merged.url, older.url);
        expect(merged.githubUrl, older.githubUrl);
        expect(merged.fetchedAt, newer.fetchedAt);
      });

      test('non-null metadata overrides the older snapshot', () {
        final older = ChannelSnapshot(
          description: 'Old description',
          fetchedAt: DateTime.utc(2024, 1, 1),
        );
        final newer = ChannelSnapshot(
          description: 'New description',
          fetchedAt: DateTime.utc(2024, 1, 2),
        );

        final merged = newer.mergedWith(older);

        expect(merged.description, 'New description');
      });

      test('empty new statuses fall back to the older statuses', () {
        final older = ChannelSnapshot(
          statuses: [
            ChannelStatus(createdAt: DateTime.utc(2024, 1, 1), message: 'ok'),
          ],
          fetchedAt: DateTime.utc(2024, 1, 1),
        );
        final newer = ChannelSnapshot(fetchedAt: DateTime.utc(2024, 1, 2));

        final merged = newer.mergedWith(older);

        expect(merged.statuses, older.statuses);
      });

      test(
        'a field missing from the newer snapshot is kept from the older',
        () {
          final older = ChannelSnapshot(
            fields: [
              FieldSnapshot(id: 1, label: 'Temp', value: 20),
              FieldSnapshot(id: 2, label: 'Humidity', value: 50),
            ],
            fetchedAt: DateTime.utc(2024, 1, 1),
          );
          final newer = ChannelSnapshot(
            fields: [FieldSnapshot(id: 1, label: 'Temp', value: 21)],
            fetchedAt: DateTime.utc(2024, 1, 2),
          );

          final merged = newer.mergedWith(older);

          expect(merged.fields, hasLength(2));
          final field1 = merged.fields.firstWhere((f) => f.id == 1);
          final field2 = merged.fields.firstWhere((f) => f.id == 2);
          expect(field1.value, 21);
          expect(field2.value, 50);
        },
      );

      test('a field present in both merges via FieldSnapshot.mergedWith', () {
        final older = ChannelSnapshot(
          fields: [FieldSnapshot(id: 1, label: 'Temp', value: 20)],
          fetchedAt: DateTime.utc(2024, 1, 1),
        );
        final newer = ChannelSnapshot(
          fields: [const FieldSnapshot(id: 1, label: 'Temp')],
          fetchedAt: DateTime.utc(2024, 1, 2),
        );

        final merged = newer.mergedWith(older);

        expect(merged.fields.single.value, 20);
      });
    });
  });
}
