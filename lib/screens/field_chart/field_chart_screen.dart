import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../api/thingspeak_api.dart';
import '../../l10n/app_localizations.dart';
import '../../models/channel.dart';
import '../../models/field.dart';
import '../../models/field_chart_settings.dart';
import '../../storage/field_settings_storage.dart';
import '../../storage/pinned_fields_storage.dart';
import '../../theme.dart';
import '../field_settings/field_settings_screen.dart';
import '../settings/settings_notifier.dart';
import 'field_chart_notifier.dart';
import 'field_table.dart';

/// Fixed padding applied around a lone data point so the chart doesn't get
/// a zero-width x-range (minX == maxX).
const _singlePointPadding = Duration(hours: 1);

/// Maximum number of bars rendered by the column chart at once — the visible
/// window is bucket-averaged down to this before rendering.
const _maxBars = 300;

class FieldChartScreen extends StatefulWidget {
  final Channel channel;
  final Field field;
  final ThingSpeakApi api;
  final SettingsNotifier settings;
  final FieldSettingsStorage fieldSettingsStorage;
  final PinnedFieldsStorage pinnedFieldsStorage;
  final VoidCallback? onPinnedChanged;

  const FieldChartScreen({
    super.key,
    required this.channel,
    required this.field,
    required this.api,
    required this.settings,
    required this.fieldSettingsStorage,
    required this.pinnedFieldsStorage,
    this.onPinnedChanged,
  });

  @override
  State<FieldChartScreen> createState() => _FieldChartScreenState();
}

class _FieldChartScreenState extends State<FieldChartScreen> {
  late final FieldChartNotifier _notifier;
  late FieldChartSettings _chartSettings;
  late bool _pinned;
  bool _showTable = false;

  @override
  void initState() {
    super.initState();
    _notifier = FieldChartNotifier(widget.api, widget.channel, widget.field);
    _chartSettings = widget.fieldSettingsStorage.settingsFor(
      widget.channel,
      widget.field.id,
    );
    _pinned = widget.pinnedFieldsStorage.isPinned(
      widget.channel,
      widget.field.id,
    );
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  Future<void> _togglePin() async {
    await widget.pinnedFieldsStorage.toggle(widget.channel, widget.field.id);
    if (!mounted) return;
    setState(() => _pinned = !_pinned);
    widget.onPinnedChanged?.call();
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FieldSettingsScreen(
          channel: widget.channel,
          field: widget.field,
          settings: _chartSettings,
          onChanged: (next) {
            widget.fieldSettingsStorage.save(
              widget.channel,
              widget.field.id,
              next,
            );
            setState(() => _chartSettings = next);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final chartTitle = _chartSettings.title ?? widget.field.displayLabel;
    return Scaffold(
      appBar: AppBar(
        title: Text(chartTitle),
        actions: [
          IconButton(
            icon: Icon(_pinned ? Icons.push_pin : Icons.push_pin_outlined),
            tooltip: _pinned ? l10n.unpinFieldTooltip : l10n.pinFieldTooltip,
            onPressed: _togglePin,
          ),
          IconButton(
            icon: Icon(_showTable ? Icons.show_chart : Icons.table_rows),
            tooltip: _showTable
                ? l10n.fieldChartTooltip
                : l10n.fieldTableTooltip,
            onPressed: () => setState(() => _showTable = !_showTable),
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: l10n.fieldSettingsTooltip,
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _notifier,
        builder: (context, _) => switch (_notifier.state) {
          FieldChartLoading() => Center(
            child: CircularProgressIndicator(semanticsLabel: l10n.labelLoading),
          ),
          FieldChartEmpty() => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(l10n.fieldChartNoValues),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _showFilterSheet(context),
                  icon: const Icon(Icons.filter_list),
                  label: Text(l10n.filterTitle),
                ),
              ],
            ),
          ),
          FieldChartError(
            :final cachedValues,
            :final errorCode,
            :final serverMessage,
          ) =>
            Builder(
              builder: (context) {
                final l10n = AppLocalizations.of(context)!;
                final message = switch (errorCode) {
                  ApiErrorCode.network => l10n.errorNetwork,
                  ApiErrorCode.credentials => l10n.errorApiCredentials,
                  ApiErrorCode.general => serverMessage ?? l10n.errorGeneral,
                };
                return Column(
                  children: [
                    Expanded(
                      child: cachedValues.isEmpty
                          ? Center(child: Text(message))
                          : _showTable
                          ? FieldTable(
                              values: cachedValues,
                              settings: widget.settings,
                              chartSettings: _chartSettings,
                            )
                          : _Chart(
                              values: cachedValues,
                              invalidAt: const [],
                              settings: widget.settings,
                              chartSettings: _chartSettings,
                              title: chartTitle,
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    _FilterButton(
                      onPressed: () => _showFilterSheet(context),
                      l10n: l10n,
                    ),
                  ],
                );
              },
            ),
          FieldChartLoaded(:final values, :final invalidAt, :final truncated) =>
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l10n.fieldChartShowingValues(values.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (truncated)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Text(
                      l10n.fieldChartTruncated,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ),
                Expanded(
                  child: _showTable
                      ? FieldTable(
                          values: values,
                          settings: widget.settings,
                          chartSettings: _chartSettings,
                        )
                      : _Chart(
                          values: values,
                          invalidAt: invalidAt,
                          settings: widget.settings,
                          chartSettings: _chartSettings,
                          title: chartTitle,
                        ),
                ),
                _FilterButton(
                  onPressed: () => _showFilterSheet(context),
                  l10n: l10n,
                ),
              ],
            ),
        },
      ),
    );
  }

  Future<void> _showFilterSheet(BuildContext context) async {
    final currentState = _notifier.state;
    final currentRange = switch (currentState) {
      FieldChartLoaded(:final range) => range,
      FieldChartEmpty(:final range) => range,
      FieldChartError(:final range) => range,
      FieldChartLoading() => DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    };

    final range = await showModalBottomSheet<DateTimeRange>(
      context: context,
      builder: (context) =>
          _FilterSheet(initialRange: currentRange, settings: widget.settings),
    );

    if (range != null) _notifier.applyFilter(range);
  }
}

class _FilterButton extends StatelessWidget {
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  const _FilterButton({required this.onPressed, required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.filter_list),
        label: Text(l10n.filterTitle),
      ),
    );
  }
}

class _Chart extends StatefulWidget {
  final List<FieldValue> values;
  final List<DateTime> invalidAt;
  final SettingsNotifier settings;
  final FieldChartSettings chartSettings;
  final String title;

  const _Chart({
    required this.values,
    required this.invalidAt,
    required this.settings,
    required this.chartSettings,
    required this.title,
  });

  @override
  State<_Chart> createState() => _ChartState();
}

class _ChartState extends State<_Chart> {
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

  /// Recomputes [_displayValues] and the derived full-range fields. These
  /// are read repeatedly per gesture frame during pinch-zoom, so they are
  /// computed once here rather than on every access.
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
  void didUpdateWidget(covariant _Chart oldWidget) {
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
    if (values.isEmpty) return widget.title;
    var min = values.first.value;
    var max = values.first.value;
    for (final v in values) {
      if (v.value < min) min = v.value;
      if (v.value > max) max = v.value;
    }
    final latest = values.last;
    return l10n.fieldChartSemantics(
      widget.title,
      values.length,
      _valueText(min, chartSettings),
      _valueText(max, chartSettings),
      _valueText(latest.value, chartSettings),
      _dateText(latest.createdAt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = Theme.of(context).extension<BrandColors>()!.dataAccent;
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
                        ? _buildBarChart(colorScheme, color, chartSettings)
                        : _buildLineChart(colorScheme, color, chartSettings),
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

  Widget _buildLineChart(
    ColorScheme colorScheme,
    Color color,
    FieldChartSettings chartSettings,
  ) {
    final isScatter = chartSettings.type == ChartType.scatter;
    final spots = _cachedSpots;

    return LineChart(
      LineChartData(
        minX: _minX,
        maxX: _maxX,
        minY: chartSettings.yMin,
        maxY: chartSettings.yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: chartSettings.type == ChartType.spline,
            isStepLineChart: chartSettings.type == ChartType.step,
            color: color,
            barWidth: isScatter ? 0 : 2,
            dotData: FlDotData(
              show: isScatter,
              getDotPainter: (_, _, _, _) =>
                  FlDotCirclePainter(radius: 2.5, color: color),
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
        _barChart(colorScheme, color, chartSettings, bars, barWidth, labelStep),
        if (bars.isEmpty)
          Text(AppLocalizations.of(context)!.fieldChartNoValuesInZoom),
      ],
    );
  }

  Widget _barChart(
    ColorScheme colorScheme,
    Color color,
    FieldChartSettings chartSettings,
    List<FieldValue> bars,
    double barWidth,
    int labelStep,
  ) {
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
        minY: chartSettings.yMin,
        maxY: chartSettings.yMax,
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

class _FilterSheet extends StatefulWidget {
  final DateTimeRange initialRange;
  final SettingsNotifier settings;

  const _FilterSheet({required this.initialRange, required this.settings});

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    _range = widget.initialRange;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.filterTitle, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ListTile(
            title: Text(l10n.filterFrom),
            subtitle: Text(widget.settings.formatDateTime(_range.start)),
            onTap: () => _pickFrom(context),
          ),
          ListTile(
            title: Text(l10n.filterTo),
            subtitle: Text(widget.settings.formatDateTime(_range.end)),
            onTap: () => _pickTo(context),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.labelCancel),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, _range),
                  child: Text(l10n.labelApply),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickFrom(BuildContext context) async {
    var dateTime = await _pickDateTime(
      context,
      initial: _range.start,
      firstDate: DateTime(2010),
      lastDate: _range.end,
    );
    if (dateTime == null) return;
    if (dateTime.isAfter(_range.end)) {
      dateTime = _range.end.subtract(const Duration(minutes: 1));
    }
    final picked = dateTime;
    setState(() => _range = DateTimeRange(start: picked, end: _range.end));
  }

  Future<void> _pickTo(BuildContext context) async {
    final now = DateTime.now();
    var dateTime = await _pickDateTime(
      context,
      initial: _range.end,
      firstDate: _range.start,
      lastDate: now,
    );
    if (dateTime == null) return;
    if (dateTime.isBefore(_range.start)) {
      dateTime = _range.start.add(const Duration(minutes: 1));
    }
    if (dateTime.isAfter(now)) dateTime = now;
    final picked = dateTime;
    setState(() => _range = DateTimeRange(start: _range.start, end: picked));
  }

  /// Combines a date picker and a time picker into a single [DateTime].
  /// Returns null if either dialog is cancelled.
  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initial,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }
}
