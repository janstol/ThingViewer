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
String formatFieldValue(double value) {
  var s = value.toStringAsFixed(_maxDecimals);
  // Very large/small magnitudes fall back to exponential form — leave as-is.
  if (!s.contains('.')) return s;
  while (s.endsWith('0') && s.split('.')[1].length > _minDecimals) {
    s = s.substring(0, s.length - 1);
  }
  return s;
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
