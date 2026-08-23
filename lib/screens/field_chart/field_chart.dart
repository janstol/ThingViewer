import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/field.dart';
import '../../models/field_chart_settings.dart';
import '../../models/field_stats.dart';
import '../../theme.dart';
import '../settings/settings_notifier.dart';

/// Fixed padding applied around a lone data point so the chart doesn't get
/// a zero-width x-range (minX == maxX).
const _singlePointPadding = Duration(hours: 1);

/// Maximum number of bars rendered by the column chart at once — the visible
/// window is bucket-averaged down to this before rendering.
const _maxBars = 300;

class FieldChart extends StatefulWidget {
  final List<FieldValue> values;
  final List<DateTime> invalidAt;
  final SettingsNotifier settings;
  final FieldChartSettings chartSettings;
  final String title;

  const FieldChart({
    super.key,
    required this.values,
    required this.invalidAt,
    required this.settings,
    required this.chartSettings,
    required this.title,
  });

  @override
  State<FieldChart> createState() => _FieldChartState();
}

class _FieldChartState extends State<FieldChart> {
  late double _minX;
  late double _maxX;

  // Raw pointer tracking — outside the gesture arena so fl_chart touch still works.
  final Map<int, Offset> _pointers = {};
  double? _lastPinchDist;
  Offset? _lastPinchMid;

  BoxConstraints? _constraints;

  // A 1-point series deltas to zero points, so this can be shorter than
  // widget.values — never call .first/.last on it without checking length.
  late List<FieldValue> _displayValues;
  late double _fullMinX;
  late double _fullMaxX;
  late double _fullRange;
  late bool _isSinglePoint;
  late List<FlSpot> _cachedSpots;

  // Min/max stats for the whole currently filtered series — not the
  // pinch-zoom window, so the marker labels always agree with the stats
  // row and don't need recomputing per gesture frame. Null for an empty
  // series (see computeFieldStats).
  FieldStats? _markerStats;

  /// Recomputes [_displayValues], the derived full-range fields, and
  /// [_markerStats]. These are read repeatedly per gesture frame during
  /// pinch-zoom, so they are computed once here rather than on every access.
  void _recomputeDisplayValues() {
    _displayValues = widget.chartSettings.showDelta
        ? deltaValues(widget.values)
        : widget.values;
    _isSinglePoint = _displayValues.length < 2;
    if (_isSinglePoint) {
      _fullMinX = 0;
      _fullMaxX = 0;
      _fullRange = 0;
    } else {
      _fullMinX = _displayValues.first.createdAt.millisecondsSinceEpoch
          .toDouble();
      _fullMaxX = _displayValues.last.createdAt.millisecondsSinceEpoch
          .toDouble();
      _fullRange = _fullMaxX - _fullMinX;
    }
    _markerStats = computeFieldStats(_statsValues);
  }

  /// Recomputes the rendered line-chart spot list. Depends on
  /// [_displayValues], [FieldChartScreen.invalidAt] and
  /// [FieldChartSettings.gapOnInvalid] only, so it stays fixed across
  /// gesture frames and only needs to change when one of those does.
  void _recomputeSpots() {
    _cachedSpots = widget.chartSettings.gapOnInvalid
        ? _spotsWithGaps()
        : [
            for (final v in _displayValues)
              FlSpot(v.createdAt.millisecondsSinceEpoch.toDouble(), v.value),
          ];
  }

  @override
  void initState() {
    super.initState();
    _recomputeDisplayValues();
    _recomputeSpots();
    if (_isSinglePoint) {
      final displayValues = _displayValues;
      final anchor = displayValues.isNotEmpty
          ? displayValues.first.createdAt
          : widget.values.last.createdAt;
      final anchorMs = anchor.millisecondsSinceEpoch.toDouble();
      final padding = _singlePointPadding.inMilliseconds.toDouble();
      _minX = anchorMs - padding;
      _maxX = anchorMs + padding;
    } else {
      _minX = _fullMinX;
      _maxX = _fullMaxX;
    }
  }

  @override
  void didUpdateWidget(covariant FieldChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final valuesChanged =
        oldWidget.values != widget.values ||
        oldWidget.chartSettings.showDelta != widget.chartSettings.showDelta;
    final spotsInputsChanged =
        valuesChanged ||
        oldWidget.invalidAt != widget.invalidAt ||
        oldWidget.chartSettings.gapOnInvalid !=
            widget.chartSettings.gapOnInvalid;
    if (valuesChanged) _recomputeDisplayValues();
    if (spotsInputsChanged) _recomputeSpots();
  }

  void _pointerDown(PointerDownEvent e) {
    if (_isSinglePoint) return;
    _pointers[e.pointer] = e.localPosition;
    if (_pointers.length == 2) {
      final pts = _pointers.values.toList();
      _lastPinchDist = (pts[0] - pts[1]).distance;
      _lastPinchMid = (pts[0] + pts[1]) / 2;
    }
  }

  void _pointerMove(PointerMoveEvent e) {
    if (_isSinglePoint) return;
    _pointers[e.pointer] = e.localPosition;
    // Only handle two-finger gestures; single finger is left to fl_chart for tooltip.
    if (_pointers.length < 2) return;
    final c = _constraints;
    if (c == null || c.maxWidth == 0) return;

    final pts = _pointers.values.toList();
    final newDist = (pts[0] - pts[1]).distance;
    final newMid = (pts[0] + pts[1]) / 2;

    if (_lastPinchDist != null &&
        _lastPinchMid != null &&
        _lastPinchDist! > 0) {
      final scale = newDist / _lastPinchDist!;
      final currentRange = _maxX - _minX;
      final newRange = (currentRange / scale).clamp(
        _fullRange / 500,
        _fullRange,
      );

      final focalFraction = (_lastPinchMid!.dx / c.maxWidth).clamp(0.0, 1.0);
      final focalData = _minX + focalFraction * currentRange;
      final panMs =
          -(newMid.dx - _lastPinchMid!.dx) / c.maxWidth * currentRange;

      double newMin = (focalData - focalFraction * newRange + panMs).clamp(
        _fullMinX,
        _fullMaxX - newRange,
      );
      setState(() {
        _minX = newMin;
        _maxX = newMin + newRange;
      });
    }
    _lastPinchDist = newDist;
    _lastPinchMid = newMid;
  }

  void _pointerUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    _lastPinchDist = null;
    _lastPinchMid = null;
  }

  void _pointerCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    _lastPinchDist = null;
    _lastPinchMid = null;
  }

  Widget? _axisName(String? label) => label != null ? Text(label) : null;

  String _valueText(double value, FieldChartSettings chartSettings) =>
      formatFieldValue(value, decimals: chartSettings.decimals);

  String _dateText(DateTime dt) => widget.settings.formatDateTime(dt);

  /// Scales a fixed axis-gutter size by the system text scale factor, so
  /// enlarged axis label text doesn't clip against a gutter sized for the
  /// default scale.
  double _scaledReservedSize(double base) =>
      MediaQuery.textScalerOf(context).scale(base);

  AxisTitles _leftTitles(FieldChartSettings chartSettings) => AxisTitles(
    axisNameWidget: _axisName(chartSettings.yAxisLabel),
    sideTitles: SideTitles(
      showTitles: true,
      reservedSize: _scaledReservedSize(48),
      getTitlesWidget: (value, meta) => SideTitleWidget(
        meta: meta,
        child: Text(
          _valueText(value, chartSettings),
          style: const TextStyle(fontSize: 10),
        ),
      ),
    ),
  );

  /// Values used for the chart's semantics summary — falls back to the raw
  /// values when the delta series is too short to summarise (e.g. a single
  /// raw point deltas to zero points).
  List<FieldValue> get _statsValues =>
      _displayValues.isNotEmpty ? _displayValues : widget.values;

  String _semanticsLabel(
    BuildContext context,
    FieldChartSettings chartSettings,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final values = _statsValues;
    final stats = computeFieldStats(values);
    if (stats == null) return widget.title;
    final latest = values.last;
    return l10n.fieldChartSemantics(
      widget.title,
      stats.count,
      _valueText(stats.min, chartSettings),
      _valueText(stats.max, chartSettings),
      _valueText(latest.value, chartSettings),
      _dateText(latest.createdAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final brand = Theme.of(context).extension<BrandColors>()!;
    final color = brand.dataAccent;
    final chartSettings = widget.chartSettings;

    return Semantics(
      label: _semanticsLabel(context, chartSettings),
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 24, 24, 8),
          child: ListenableBuilder(
            listenable: widget.settings,
            builder: (context, _) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  _constraints = constraints;
                  return Listener(
                    onPointerDown: _pointerDown,
                    onPointerMove: _pointerMove,
                    onPointerUp: _pointerUp,
                    onPointerCancel: _pointerCancel,
                    child: chartSettings.type == ChartType.column
                        ? _buildBarChart(
                            colorScheme,
                            brand,
                            color,
                            chartSettings,
                          )
                        : _buildLineChart(
                            colorScheme,
                            brand,
                            color,
                            chartSettings,
                          ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  /// Merges [_displayValues] and [FieldChartScreen]'s invalid timestamps into
  /// one time-sorted sequence, emitting [FlSpot.nullSpot] for each invalid
  /// entry so the line breaks there instead of connecting across it.
  List<FlSpot> _spotsWithGaps() {
    final points = <(DateTime, double?)>[
      for (final v in _displayValues) (v.createdAt, v.value),
      for (final t in widget.invalidAt) (t, null),
    ]..sort((a, b) => a.$1.compareTo(b.$1));

    return [
      for (final (t, v) in points)
        v == null
            ? FlSpot.nullSpot
            : FlSpot(t.millisecondsSinceEpoch.toDouble(), v),
    ];
  }

  /// Dashed horizontal reference lines at [FieldStats.min]/[FieldStats.max]
  /// of the whole currently filtered series — not the pinch-zoom window, so
  /// the labels always agree with the stats row and don't need recomputing
  /// per gesture frame. [sharedDecimals] keeps the label text formatted
  /// identically to the stats row.
  ExtraLinesData _markerLines(
    ColorScheme colorScheme,
    BrandColors brand,
    FieldChartSettings chartSettings,
  ) {
    final stats = _markerStats;
    if (stats == null || !(chartSettings.markMin || chartSettings.markMax)) {
      return const ExtraLinesData();
    }
    final l10n = AppLocalizations.of(context)!;
    final decimals = sharedDecimals(stats, chartSettings.decimals);
    String text(double v) => formatFieldValue(v, decimals: decimals);
    // A solid backing behind the label text, not just its colour, so it
    // stays legible wherever the line lands — a column chart's bars fill
    // solid to the baseline, and the min marker often sits right on top of
    // one, where the marker's own colour alone lost contrast against it.
    final style = TextStyle(
      color: brand.markerAccent,
      fontWeight: FontWeight.bold,
      fontSize: 10,
      backgroundColor: colorScheme.surface,
    );

    // A flat series (min == max) with both toggles on would draw two
    // coincident dashed lines with overlapping labels — collapse to one.
    final skipMin = stats.min == stats.max && chartSettings.markMax;

    return ExtraLinesData(
      horizontalLines: [
        if (chartSettings.markMax)
          HorizontalLine(
            y: stats.max,
            color: brand.markerAccent,
            strokeWidth: 1,
            dashArray: const [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              style: style,
              labelResolver: (_) =>
                  '${l10n.fieldChartStatMax} ${text(stats.max)}',
            ),
          ),
        if (chartSettings.markMin && !skipMin)
          HorizontalLine(
            y: stats.min,
            color: brand.markerAccent,
            strokeWidth: 1,
            dashArray: const [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.bottomRight,
              style: style,
              labelResolver: (_) =>
                  '${l10n.fieldChartStatMin} ${text(stats.min)}',
            ),
          ),
      ],
    );
  }

  /// Y-axis bounds to pass to the chart. When a bound isn't manually
  /// overridden and its marker is on, pads it outward from the series
  /// extreme by a fraction of the data range — otherwise the marker's line
  /// and label sit exactly on the chart's own auto-computed axis boundary
  /// and collide with the axis's own tick label there (and, at the bottom,
  /// with the rotated x-axis date labels). A manually set
  /// [FieldChartSettings.yMin]/[FieldChartSettings.yMax] is left untouched
  /// — that's a deliberate user choice, not this widget's to second-guess.
  (double?, double?) _effectiveYBounds(FieldChartSettings chartSettings) {
    final stats = _markerStats;
    if (stats == null) return (chartSettings.yMin, chartSettings.yMax);

    final range = stats.max - stats.min;
    // A flat (or near-flat) series has no range to derive a margin from —
    // fall back to a fraction of the value's own magnitude, or a constant
    // for an all-zero series.
    final margin = range > 0
        ? range * 0.1
        : (stats.max != 0 ? stats.max.abs() * 0.1 : 1.0);

    final minY = chartSettings.yMin ??
        (chartSettings.markMin ? stats.min - margin : null);
    final maxY = chartSettings.yMax ??
        (chartSettings.markMax ? stats.max + margin : null);
    return (minY, maxY);
  }

  /// Whether [spot] is the marker dot for a toggled-on extreme. Exact
  /// double comparison is safe here — [_cachedSpots] and [_markerStats] are
  /// both derived from [_displayValues] without any intervening rounding,
  /// so a real match compares bit-for-bit equal.
  bool _isMarkerSpot(FlSpot spot, FieldChartSettings chartSettings) {
    final stats = _markerStats;
    if (stats == null) return false;
    if (chartSettings.markMax &&
        spot.x == stats.maxAt.millisecondsSinceEpoch.toDouble() &&
        spot.y == stats.max) {
      return true;
    }
    if (chartSettings.markMin &&
        spot.x == stats.minAt.millisecondsSinceEpoch.toDouble() &&
        spot.y == stats.min) {
      return true;
    }
    return false;
  }

  Widget _buildLineChart(
    ColorScheme colorScheme,
    BrandColors brand,
    Color color,
    FieldChartSettings chartSettings,
  ) {
    final isScatter = chartSettings.type == ChartType.scatter;
    final spots = _cachedSpots;
    final hasMarkers =
        _markerStats != null &&
        (chartSettings.markMin || chartSettings.markMax);
    final (minY, maxY) = _effectiveYBounds(chartSettings);

    return LineChart(
      LineChartData(
        minX: _minX,
        maxX: _maxX,
        minY: minY,
        maxY: maxY,
        extraLinesData: _markerLines(colorScheme, brand, chartSettings),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: chartSettings.type == ChartType.spline,
            isStepLineChart: chartSettings.type == ChartType.step,
            color: color,
            barWidth: isScatter ? 0 : 2,
            dotData: FlDotData(
              show: isScatter || hasMarkers,
              checkToShowDot: (spot, _) =>
                  isScatter || _isMarkerSpot(spot, chartSettings),
              getDotPainter: (spot, _, _, _) => _isMarkerSpot(
                spot,
                chartSettings,
              )
                  ? FlDotCirclePainter(
                      radius: 4,
                      color: brand.markerAccent,
                      strokeWidth: 1.5,
                      strokeColor: colorScheme.surface,
                    )
                  : FlDotCirclePainter(radius: 2.5, color: color),
            ),
            belowBarData: BarAreaData(
              show: !isScatter,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  color.withValues(alpha: 0.2),
                  color.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(chartSettings),
          bottomTitles: AxisTitles(
            axisNameWidget: _axisName(chartSettings.xAxisLabel),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _scaledReservedSize(52),
              getTitlesWidget: (value, meta) {
                final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return SideTitleWidget(
                  meta: meta,
                  angle: -0.6,
                  child: Text(
                    widget.settings.formatDate(dt),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItems: (spots) => spots.map((s) {
              final dt = DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
              return LineTooltipItem(
                '${_valueText(s.y, chartSettings)}\n',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: _dateText(dt),
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildBarChart(
    ColorScheme colorScheme,
    BrandColors brand,
    Color color,
    FieldChartSettings chartSettings,
  ) {
    final slice = _displayValues.where((v) {
      final ms = v.createdAt.millisecondsSinceEpoch;
      return ms >= _minX && ms <= _maxX;
    }).toList();
    final bars = bucketAverage(slice, _maxBars);

    final barWidth = bars.isEmpty || _constraints == null
        ? 8.0
        : ((_constraints!.maxWidth / bars.length) * 0.7).clamp(1.0, 16.0);
    final labelStep = bars.isEmpty ? 1 : (bars.length / 5).ceil();

    return Stack(
      alignment: Alignment.center,
      children: [
        _barChart(
          colorScheme,
          brand,
          color,
          chartSettings,
          bars,
          barWidth,
          labelStep,
        ),
        if (bars.isEmpty)
          Text(AppLocalizations.of(context)!.fieldChartNoValuesInZoom),
      ],
    );
  }

  Widget _barChart(
    ColorScheme colorScheme,
    BrandColors brand,
    Color color,
    FieldChartSettings chartSettings,
    List<FieldValue> bars,
    double barWidth,
    int labelStep,
  ) {
    final (minY, maxY) = _effectiveYBounds(chartSettings);
    return BarChart(
      // The bar count changes on every frame during pinch-zoom/pan (each
      // rebuild re-buckets the visible window). fl_chart's default 150ms
      // implicit animation lerps between old/new BarChartData, and its
      // internal touch handler can read a bar-position cache built from a
      // still-animating group count against the newer (shorter) target
      // list, throwing RangeError mid-gesture. Disabling the animation
      // keeps data and touch cache in sync.
      duration: Duration.zero,
      BarChartData(
        minY: minY,
        maxY: maxY,
        // Bars are bucket-averaged (bucketAverage, <= _maxBars), so the true
        // extreme reading may not survive as a bar value — only the
        // labeled reference line is drawn here, no dot. The line can sit
        // above the tallest bar without clipping since it marks the real
        // reading, not a bucket average.
        extraLinesData: _markerLines(colorScheme, brand, chartSettings),
        barGroups: [
          for (var i = 0; i < bars.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: bars[i].value,
                  color: color,
                  width: barWidth,
                ),
              ],
            ),
        ],
        titlesData: FlTitlesData(
          leftTitles: _leftTitles(chartSettings),
          bottomTitles: AxisTitles(
            axisNameWidget: _axisName(chartSettings.xAxisLabel),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: _scaledReservedSize(52),
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 ||
                    index >= bars.length ||
                    index % labelStep != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  angle: -0.6,
                  child: Text(
                    widget.settings.formatDate(bars[index].createdAt),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        gridData: const FlGridData(show: true),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => colorScheme.inverseSurface,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              if (groupIndex < 0 || groupIndex >= bars.length) return null;
              return BarTooltipItem(
                '${_valueText(rod.toY, chartSettings)}\n',
                TextStyle(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: _dateText(bars[groupIndex].createdAt),
                    style: TextStyle(
                      color: colorScheme.onInverseSurface.withValues(
                        alpha: 0.7,
                      ),
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}