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
  final bool showSum;
  final bool showAverage;
  final bool showMin;
  final bool showMax;
  final bool markMin;
  final bool markMax;

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
    this.showSum = true,
    this.showAverage = true,
    this.showMin = true,
    this.showMax = true,
    this.markMin = false,
    this.markMax = false,
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
      gapOnInvalid == false &&
      showSum == true &&
      showAverage == true &&
      showMin == true &&
      showMax == true &&
      markMin == false &&
      markMax == false;

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
    bool? showSum,
    bool? showAverage,
    bool? showMin,
    bool? showMax,
    bool? markMin,
    bool? markMax,
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
      showSum: showSum ?? this.showSum,
      showAverage: showAverage ?? this.showAverage,
      showMin: showMin ?? this.showMin,
      showMax: showMax ?? this.showMax,
      markMin: markMin ?? this.markMin,
      markMax: markMax ?? this.markMax,
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
    // These four default to true (shown), unlike the flags above, so only
    // the opted-out (false) case needs to be persisted.
    if (!showSum) 'showSum': showSum,
    if (!showAverage) 'showAverage': showAverage,
    if (!showMin) 'showMin': showMin,
    if (!showMax) 'showMax': showMax,
    if (markMin) 'markMin': markMin,
    if (markMax) 'markMax': markMax,
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
        showSum: json['showSum'] as bool? ?? true,
        showAverage: json['showAverage'] as bool? ?? true,
        showMin: json['showMin'] as bool? ?? true,
        showMax: json['showMax'] as bool? ?? true,
        markMin: json['markMin'] as bool? ?? false,
        markMax: json['markMax'] as bool? ?? false,
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
      gapOnInvalid == other.gapOnInvalid &&
      showSum == other.showSum &&
      showAverage == other.showAverage &&
      showMin == other.showMin &&
      showMax == other.showMax &&
      markMin == other.markMin &&
      markMax == other.markMax;

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
    Object.hash(showSum, showAverage, showMin, showMax),
    Object.hash(markMin, markMax),
  );
}
