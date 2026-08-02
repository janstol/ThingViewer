import '../models/field.dart';

enum CsvExportMode { raw, formatted }

/// Quotes [cell] per RFC 4180 if it contains a comma, double quote, or line
/// break: wraps it in `"` and doubles any inner `"`.
String _csvCell(String cell) {
  if (!cell.contains(RegExp(r'[,"\r\n]'))) return cell;
  return '"${cell.replaceAll('"', '""')}"';
}

/// Builds a CSV document of [values] in the order given — the caller is
/// expected to pass them chronologically (oldest first), since this never
/// sorts or reverses.
///
/// In [CsvExportMode.raw], timestamps are UTC ISO 8601 (with a trailing `Z`)
/// and values are unrounded — [FieldValue.createdAt] is stored as a local
/// [DateTime] (see `ThingSpeakApi`'s `.toLocal()` on parse), and emitting
/// that local time via [DateTime.toIso8601String] with no offset suffix
/// would be ambiguous in a file. In [CsvExportMode.formatted], [formatTimestamp]
/// and [decimals] apply the app's own display formatting instead.
String buildFieldCsv(
  List<FieldValue> values, {
  required CsvExportMode mode,
  required String Function(DateTime) formatTimestamp,
  int? decimals,
}) {
  final buffer = StringBuffer('timestamp,value\r\n');
  for (final v in values) {
    final timestamp = switch (mode) {
      CsvExportMode.raw => v.createdAt.toUtc().toIso8601String(),
      CsvExportMode.formatted => formatTimestamp(v.createdAt),
    };
    final value = switch (mode) {
      CsvExportMode.raw => v.value.toString(),
      CsvExportMode.formatted => formatFieldValue(v.value, decimals: decimals),
    };
    buffer
      ..write(_csvCell(timestamp))
      ..write(',')
      ..write(_csvCell(value))
      ..write('\r\n');
  }
  return buffer.toString();
}
