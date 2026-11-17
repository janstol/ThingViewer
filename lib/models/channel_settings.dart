import 'range_preset.dart';

/// Local-only preferences for a whole channel. Like [Channel.name], these are
/// never sent to ThingSpeak.
class ChannelSettings {
  /// Window every chart in the channel opens on, unless the field has its
  /// own `FieldChartSettings.defaultRange`. Null means the app default.
  final RangePreset? defaultRange;

  /// Whether charts in the channel open on the last range picked in any of
  /// its charts during this app session.
  final bool rememberRange;

  const ChannelSettings({this.defaultRange, this.rememberRange = false});

  static const defaults = ChannelSettings();

  bool get isDefault => defaultRange == null && !rememberRange;

  Map<String, dynamic> toJson() => {
    if (defaultRange != null) 'defaultRange': defaultRange!.name,
    if (rememberRange) 'rememberRange': true,
  };

  factory ChannelSettings.fromJson(Map<String, dynamic> json) =>
      ChannelSettings(
        defaultRange: RangePreset.tryParse(json['defaultRange']),
        rememberRange: json['rememberRange'] == true,
      );

  @override
  bool operator ==(Object other) =>
      other is ChannelSettings &&
      defaultRange == other.defaultRange &&
      rememberRange == other.rememberRange;

  @override
  int get hashCode => Object.hash(defaultRange, rememberRange);
}
