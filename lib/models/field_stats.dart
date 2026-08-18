import 'field.dart';

/// Aggregate stats for a series of [FieldValue]s over some range.
class FieldStats {
  final int count;
  final double sum;
  final double min;
  final double max;

  const FieldStats({
    required this.count,
    required this.sum,
    required this.min,
    required this.max,
  });

  /// `count` is always >= 1 on an instance of this class, see
  /// [computeFieldStats].
  double get average => sum / count;
}

/// Reduces [values] to count/sum/min/max in a single pass. Returns null for
/// an empty list, so "no data" stays distinguishable from "sums to zero" —
/// a real outcome for a delta series with no net change over the window.
///
/// [Field.values] is finite-only by construction (`NaN`/`Infinity` readings
/// live in [Field.invalidAt] instead), so this never has to guard against
/// non-finite input. Unlike ThingSpeak's own `average` request parameter,
/// which counts a `NaN` reading as `0`, there is nothing to count here at
/// all — non-finite readings are simply absent from [values].
FieldStats? computeFieldStats(List<FieldValue> values) {
  if (values.isEmpty) return null;
  var sum = 0.0;
  var min = values.first.value;
  var max = values.first.value;
  for (final v in values) {
    sum += v.value;
    if (v.value < min) min = v.value;
    if (v.value > max) max = v.value;
  }
  return FieldStats(count: values.length, sum: sum, min: min, max: max);
}
