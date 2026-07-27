class FieldValue {
  final DateTime createdAt;
  final double value;

  const FieldValue({required this.createdAt, required this.value});
}

/// Maximum decimal places shown for a field value. Beyond this, readings are
/// dominated by float noise rather than sensor precision.
const _maxDecimals = 6;
const _minDecimals = 2;

/// Formats a field value for display: at least [_minDecimals] decimal places,
/// at most [_maxDecimals], with trailing zeros trimmed in between.
///
/// ThingSpeak reports values as strings of arbitrary precision; rounding every
/// reading to two decimals hides real movement in high-precision channels.
///
/// Pass [decimals] to override the auto behaviour with a fixed number of
/// decimal places (a per-field user setting).
String formatFieldValue(double value, {int? decimals}) {
  if (decimals != null) return value.toStringAsFixed(decimals);

  var s = value.toStringAsFixed(_maxDecimals);
  // Very large/small magnitudes fall back to exponential form — leave as-is.
  if (!s.contains('.')) return s;
  while (s.endsWith('0') && s.split('.')[1].length > _minDecimals) {
    s = s.substring(0, s.length - 1);
  }
  return s;
}

/// Pairs consecutive readings into `value[n] - value[n-1]`, keeping `t[n]`.
///
/// Turns a monotonically increasing counter into a per-reading rate. Returns
/// an empty list for inputs with fewer than 2 values.
List<FieldValue> deltaValues(List<FieldValue> values) {
  if (values.length < 2) return [];
  return [
    for (var i = 1; i < values.length; i++)
      FieldValue(
        createdAt: values[i].createdAt,
        value: values[i].value - values[i - 1].value,
      ),
  ];
}

/// Downsamples [values] to at most [maxPoints] points by averaging
/// contiguous index-based buckets.
///
/// Returns [values] unchanged when it already fits within [maxPoints] (or
/// [maxPoints] is less than 1). Each emitted point's timestamp is the
/// midpoint between its bucket's first and last timestamp — index-based
/// rather than time-based, since this is a display-only "N points → M
/// points" reduction, not real aggregation.
List<FieldValue> bucketAverage(List<FieldValue> values, int maxPoints) {
  if (maxPoints < 1 || values.length <= maxPoints) return values;

  final result = <FieldValue>[];
  for (var i = 0; i < maxPoints; i++) {
    final start = i * values.length ~/ maxPoints;
    final end = (i + 1) * values.length ~/ maxPoints;
    final bucket = values.sublist(start, end);
    final sum = bucket.fold<double>(0, (acc, v) => acc + v.value);
    final firstMs = bucket.first.createdAt.millisecondsSinceEpoch;
    final lastMs = bucket.last.createdAt.millisecondsSinceEpoch;
    result.add(
      FieldValue(
        createdAt: DateTime.fromMillisecondsSinceEpoch((firstMs + lastMs) ~/ 2),
        value: sum / bucket.length,
      ),
    );
  }
  return result;
}

class Field {
  final int id;
  final String? label;
  final List<FieldValue> values;

  /// Timestamps of readings that parsed as non-finite (`NaN`/`Infinity`).
  ///
  /// Kept separate from [values] so the latter stays finite-only, as
  /// [lastValue], [deltaValues] and [bucketAverage] all depend on that.
  final List<DateTime> invalidAt;

  const Field({
    required this.id,
    this.label,
    this.values = const [],
    this.invalidAt = const [],
  });

  String get displayLabel => label?.isNotEmpty == true ? label! : 'Field $id';

  double? get lastValue => values.isEmpty ? null : values.last.value;
  DateTime? get lastUpdated => values.isEmpty ? null : values.last.createdAt;
}
