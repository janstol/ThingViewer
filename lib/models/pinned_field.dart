import '../models/channel.dart';

double? _parseDouble(dynamic value) => value is num ? value.toDouble() : null;

/// A field pinned for the channel-list dashboard, carrying both its identity
/// and the last-fetched snapshot so the dashboard can render before any
/// network call completes.
class PinnedField {
  final String serverUrl;
  final int channelId;
  final int fieldId;
  final String? label;
  final double? value;
  final DateTime? valueAt;
  final DateTime? fetchedAt;

  const PinnedField({
    required this.serverUrl,
    required this.channelId,
    required this.fieldId,
    this.label,
    this.value,
    this.valueAt,
    this.fetchedAt,
  });

  bool matches(Channel channel) =>
      serverUrl == channel.serverUrl && channelId == channel.id;

  PinnedField copyWith({
    String? serverUrl,
    int? channelId,
    int? fieldId,
    String? label,
    double? value,
    DateTime? valueAt,
    DateTime? fetchedAt,
  }) {
    return PinnedField(
      serverUrl: serverUrl ?? this.serverUrl,
      channelId: channelId ?? this.channelId,
      fieldId: fieldId ?? this.fieldId,
      label: label ?? this.label,
      value: value ?? this.value,
      valueAt: valueAt ?? this.valueAt,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'channelId': channelId,
    'fieldId': fieldId,
    if (label != null) 'label': label,
    if (value != null) 'value': value,
    if (valueAt != null) 'valueAt': valueAt!.toIso8601String(),
    if (fetchedAt != null) 'fetchedAt': fetchedAt!.toIso8601String(),
  };

  factory PinnedField.fromJson(Map<String, dynamic> json) => PinnedField(
    serverUrl: json['serverUrl'] as String,
    channelId: json['channelId'] as int,
    fieldId: json['fieldId'] as int,
    label: json['label'] as String?,
    value: _parseDouble(json['value']),
    valueAt: json['valueAt'] != null
        ? DateTime.tryParse(json['valueAt'] as String)
        : null,
    fetchedAt: json['fetchedAt'] != null
        ? DateTime.tryParse(json['fetchedAt'] as String)
        : null,
  );

  @override
  bool operator ==(Object other) =>
      other is PinnedField &&
      serverUrl == other.serverUrl &&
      channelId == other.channelId &&
      fieldId == other.fieldId;

  @override
  int get hashCode => Object.hash(serverUrl, channelId, fieldId);
}
