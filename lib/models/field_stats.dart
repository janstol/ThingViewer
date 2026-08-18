import 'field.dart';

/// Aggregate stats for a series of [FieldValue]s over some range.
class FieldStats {
  final int count;
  final double sum;
  final double min;
  final double max;

  /// When [min]/[max] occurred. On a tie, the first occurrence wins — see
  /// [computeFieldStats].
  final DateTime minAt;
  final DateTime maxAt;

  const FieldStats({
    required this.count,
    required this.sum,
    required this.min,
    required this.max,
    required this.minAt,
    required this.maxAt,
  });

  /// `count` is always >= 1 on an instance of this class, see
  /// [computeFieldStats].
  double get average => sum / count;
}

/// Reduces [values] to count/sum/min/max (and where they occurred) in a
/// single pass. Returns null for an empty list, so "no data" stays
/// distinguishable from "sums to zero" — a real outcome for a delta series
/// with no net change over the window.
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
  var minAt = values.first.createdAt;
  var max = values.first.value;
  var maxAt = values.first.createdAt;
  for (final v in values) {
    sum += v.value;
    // Strict `<`/`>` — first occurrence wins on a tie.
    if (v.value < min) {
      min = v.value;
      minAt = v.createdAt;
    }
    if (v.value > max) {
      max = v.value;
      maxAt = v.createdAt;
    }
  }
  return FieldStats(
    count: values.length,
    sum: sum,
    min: min,
    max: max,
    minAt: minAt,
    maxAt: maxAt,
  );
}

/// One decimal count shared by every number derived from [stats] — the
/// wider of what [FieldStats.min] and [FieldStats.max] need in auto mode
/// (see [autoDecimalsFor]), or [override] when a fixed
/// [FieldChartSettings.decimals] is set. Used to keep the stats row and the
/// on-chart marker labels formatted identically.
int? sharedDecimals(FieldStats stats, int? override) =>
    override ??
    [
      autoDecimalsFor(stats.min),
      autoDecimalsFor(stats.max),
    ].reduce((a, b) => a > b ? a : b);
