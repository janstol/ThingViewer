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

class Field {
  final int id;
  final String? label;
  final List<FieldValue> values;

  const Field({required this.id, this.label, this.values = const []});

  String get displayLabel => label?.isNotEmpty == true ? label! : 'Field $id';

  double? get lastValue => values.isEmpty ? null : values.last.value;
  DateTime? get lastUpdated => values.isEmpty ? null : values.last.createdAt;
}
