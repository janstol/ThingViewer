import 'package:flutter_test/flutter_test.dart';
import 'package:thingviewer/export/csv_export.dart';
import 'package:thingviewer/models/field.dart';

String _fmt(DateTime dt) => '${dt.year}-formatted';

void main() {
  group('buildFieldCsv', () {
    test('header row is always timestamp,value', () {
      final csv = buildFieldCsv(
        const [],
        mode: CsvExportMode.raw,
        formatTimestamp: _fmt,
      );
      expect(csv, 'timestamp,value\r\n');
    });

    test('raw mode emits UTC ISO 8601 timestamps with a Z suffix and '
        'unrounded values', () {
      final local = DateTime(2026, 1, 15, 10, 30);
      final csv = buildFieldCsv(
        [FieldValue(createdAt: local, value: 12.345678901)],
        mode: CsvExportMode.raw,
        formatTimestamp: _fmt,
      );
      final expectedTimestamp = local.toUtc().toIso8601String();
      expect(expectedTimestamp, endsWith('Z'));
      expect(
        csv,
        'timestamp,value\r\n$expectedTimestamp,12.345678901\r\n',
      );
    });

    test('formatted mode uses formatTimestamp and formatFieldValue', () {
      final dt = DateTime(2026, 1, 15, 10, 30);
      final csv = buildFieldCsv(
        [FieldValue(createdAt: dt, value: 12.3456789)],
        mode: CsvExportMode.formatted,
        formatTimestamp: _fmt,
      );
      expect(csv, 'timestamp,value\r\n2026-formatted,12.345679\r\n');
    });

    test('decimals override applies in formatted mode', () {
      final dt = DateTime(2026, 1, 15, 10, 30);
      final csv = buildFieldCsv(
        [FieldValue(createdAt: dt, value: 12.3456789)],
        mode: CsvExportMode.formatted,
        formatTimestamp: _fmt,
        decimals: 2,
      );
      expect(csv, 'timestamp,value\r\n2026-formatted,12.35\r\n');
    });

    test('a cell containing a comma and a quote is RFC 4180 quoted', () {
      final dt = DateTime(2026, 1, 15, 10, 30);
      final csv = buildFieldCsv(
        [FieldValue(createdAt: dt, value: 1)],
        mode: CsvExportMode.formatted,
        formatTimestamp: (_) => '15, Jan "2026"',
        decimals: 0,
      );
      expect(csv, 'timestamp,value\r\n"15, Jan ""2026""",1\r\n');
    });

    test('rows are written in the order given, not re-sorted or reversed', () {
      final oldest = DateTime(2026, 1, 1);
      final middle = DateTime(2026, 1, 2);
      final newest = DateTime(2026, 1, 3);
      final csv = buildFieldCsv(
        [
          FieldValue(createdAt: oldest, value: 1),
          FieldValue(createdAt: middle, value: 2),
          FieldValue(createdAt: newest, value: 3),
        ],
        mode: CsvExportMode.raw,
        formatTimestamp: _fmt,
      );
      final lines = csv.split('\r\n');
      expect(lines[1], startsWith(oldest.toUtc().toIso8601String()));
      expect(lines[2], startsWith(middle.toUtc().toIso8601String()));
      expect(lines[3], startsWith(newest.toUtc().toIso8601String()));
    });

    test('empty values input produces only the header row', () {
      final csv = buildFieldCsv(
        const [],
        mode: CsvExportMode.formatted,
        formatTimestamp: _fmt,
      );
      expect(csv, 'timestamp,value\r\n');
    });
  });
}
