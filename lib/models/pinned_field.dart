import '../models/channel.dart';

/// A field pinned for the channel-list dashboard.
///
/// Identity only — its last-known value is resolved from
/// `ChannelSnapshotStorage`, the same per-channel cache the channel detail
/// screen uses.
class PinnedField {
  final String serverUrl;
  final int channelId;
  final int fieldId;

  const PinnedField({
    required this.serverUrl,
    required this.channelId,
    required this.fieldId,
  });

  bool matches(Channel channel) =>
      serverUrl == channel.serverUrl && channelId == channel.id;

  PinnedField copyWith({String? serverUrl, int? channelId, int? fieldId}) {
    return PinnedField(
      serverUrl: serverUrl ?? this.serverUrl,
      channelId: channelId ?? this.channelId,
      fieldId: fieldId ?? this.fieldId,
    );
  }

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'channelId': channelId,
    'fieldId': fieldId,
  };

  factory PinnedField.fromJson(Map<String, dynamic> json) => PinnedField(
    serverUrl: json['serverUrl'] as String,
    channelId: json['channelId'] as int,
    fieldId: json['fieldId'] as int,
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
