enum ChartType { line, spline, step, column, scatter }

ChartType _parseType(dynamic value) {
  for (final t in ChartType.values) {
    if (t.name == value) return t;
  }
  return ChartType.line;
}

double? _parseDouble(dynamic value) => value is num ? value.toDouble() : null;

int? _parseInt(dynamic value) =>
    value is int ? value : (value is num ? value.toInt() : null);

/// Presentation-only overrides for a single field's chart. ThingSpeak has no
/// concept of a per-field chart type or axis labels — everything here is a
/// local override layered on top of API data.
class FieldChartSettings {
  final ChartType type;
  final String? title;
  final String? xAxisLabel;
  final String? yAxisLabel;
  final double? yMin;
  final double? yMax;
  final int? decimals;
  final bool showDelta;
  final bool gapOnInvalid;

  const FieldChartSettings({
    this.type = ChartType.line,
    this.title,
    this.xAxisLabel,
    this.yAxisLabel,
    this.yMin,
    this.yMax,
    this.decimals,
    this.showDelta = false,
    this.gapOnInvalid = false,
  });

  static const defaults = FieldChartSettings();

  bool get isDefault =>
      type == ChartType.line &&
      title == null &&
      xAxisLabel == null &&
      yAxisLabel == null &&
      yMin == null &&
      yMax == null &&
      decimals == null &&
      showDelta == false &&
      gapOnInvalid == false;

  FieldChartSettings copyWith({
    ChartType? type,
    String? title,
    String? xAxisLabel,
    String? yAxisLabel,
    double? yMin,
    double? yMax,
    int? decimals,
    bool? showDelta,
    bool? gapOnInvalid,
  }) {
    return FieldChartSettings(
      type: type ?? this.type,
      title: title ?? this.title,
      xAxisLabel: xAxisLabel ?? this.xAxisLabel,
      yAxisLabel: yAxisLabel ?? this.yAxisLabel,
      yMin: yMin ?? this.yMin,
      yMax: yMax ?? this.yMax,
      decimals: decimals ?? this.decimals,
      showDelta: showDelta ?? this.showDelta,
      gapOnInvalid: gapOnInvalid ?? this.gapOnInvalid,
    );
  }

  Map<String, dynamic> toJson() => {
    if (type != ChartType.line) 'type': type.name,
    if (title != null) 'title': title,
    if (xAxisLabel != null) 'xAxisLabel': xAxisLabel,
    if (yAxisLabel != null) 'yAxisLabel': yAxisLabel,
    if (yMin != null) 'yMin': yMin,
    if (yMax != null) 'yMax': yMax,
    if (decimals != null) 'decimals': decimals,
    if (showDelta) 'showDelta': showDelta,
    if (gapOnInvalid) 'gapOnInvalid': gapOnInvalid,
  };

  factory FieldChartSettings.fromJson(Map<String, dynamic> json) =>
      FieldChartSettings(
        type: _parseType(json['type']),
        title: json['title'] as String?,
        xAxisLabel: json['xAxisLabel'] as String?,
        yAxisLabel: json['yAxisLabel'] as String?,
        yMin: _parseDouble(json['yMin']),
        yMax: _parseDouble(json['yMax']),
        decimals: _parseInt(json['decimals']),
        showDelta: json['showDelta'] as bool? ?? false,
        gapOnInvalid: json['gapOnInvalid'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is FieldChartSettings &&
      type == other.type &&
      title == other.title &&
      xAxisLabel == other.xAxisLabel &&
      yAxisLabel == other.yAxisLabel &&
      yMin == other.yMin &&
      yMax == other.yMax &&
      decimals == other.decimals &&
      showDelta == other.showDelta &&
      gapOnInvalid == other.gapOnInvalid;

  @override
  int get hashCode => Object.hash(
    type,
    title,
    xAxisLabel,
    yAxisLabel,
    yMin,
    yMax,
    decimals,
    showDelta,
    gapOnInvalid,
  );
}
