import 'channel_status.dart';

double? _parseDouble(dynamic value) => value is num ? value.toDouble() : null;

/// A field's last-known value, cached alongside [ChannelSnapshot].
class FieldSnapshot {
  final int id;
  final String? label;
  final double? value;
  final DateTime? valueAt;

  const FieldSnapshot({required this.id, this.label, this.value, this.valueAt});

  Map<String, dynamic> toJson() => {
    'id': id,
    if (label != null) 'label': label,
    if (value != null) 'value': value,
    if (valueAt != null) 'valueAt': valueAt!.toIso8601String(),
  };

  factory FieldSnapshot.fromJson(Map<String, dynamic> json) => FieldSnapshot(
    id: json['id'] as int,
    label: json['label'] as String?,
    value: _parseDouble(json['value']),
    valueAt: json['valueAt'] != null
        ? DateTime.tryParse(json['valueAt'] as String)
        : null,
  );

  /// Merges this (newer) snapshot over [older]: a null [value] keeps the
  /// older value/valueAt pair, and a null [label] keeps the older label —
  /// a writer that didn't recover this field shouldn't blank what an
  /// earlier writer already knew.
  FieldSnapshot mergedWith(FieldSnapshot older) {
    final keepOlderValue = value == null;
    return FieldSnapshot(
      id: id,
      label: label ?? older.label,
      value: keepOlderValue ? older.value : value,
      valueAt: keepOlderValue ? older.valueAt : valueAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FieldSnapshot &&
      id == other.id &&
      label == other.label &&
      value == other.value &&
      valueAt == other.valueAt;

  @override
  int get hashCode => Object.hash(id, label, value, valueAt);
}

/// Last-known state of a channel, cached per-channel so the channel detail
/// screen and the pinned-fields dashboard can render before any network call
/// completes.
class ChannelSnapshot {
  final String? description;
  final String? url;
  final String? githubUrl;
  final List<FieldSnapshot> fields;
  final List<ChannelStatus> statuses;
  final DateTime fetchedAt;

  /// Statuses are trimmed to this many most-recent entries on write, so the
  /// cache stays small — an offline status log may show fewer entries than
  /// a live one.
  static const maxStatuses = 50;

  ChannelSnapshot({
    this.description,
    this.url,
    this.githubUrl,
    this.fields = const [],
    List<ChannelStatus> statuses = const [],
    required this.fetchedAt,
  }) : statuses = statuses.length > maxStatuses
           ? statuses.sublist(statuses.length - maxStatuses)
           : statuses;

  Map<String, dynamic> toJson() => {
    if (description != null) 'description': description,
    if (url != null) 'url': url,
    if (githubUrl != null) 'githubUrl': githubUrl,
    'fields': fields.map((f) => f.toJson()).toList(),
    'statuses': statuses.map((s) => s.toJson()).toList(),
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  factory ChannelSnapshot.fromJson(Map<String, dynamic> json) {
    final fetchedAt =
        DateTime.tryParse(json['fetchedAt'] as String? ?? '') ??
        DateTime.now();
    final fieldsJson = json['fields'] as List<dynamic>? ?? [];
    final statusesJson = json['statuses'] as List<dynamic>? ?? [];
    return ChannelSnapshot(
      description: json['description'] as String?,
      url: json['url'] as String?,
      githubUrl: json['githubUrl'] as String?,
      fields: fieldsJson
          .map((e) => FieldSnapshot.fromJson(e as Map<String, dynamic>))
          .toList(),
      statuses: statusesJson
          .whereType<Map<String, dynamic>>()
          .map(ChannelStatus.fromJson)
          .whereType<ChannelStatus>()
          .toList(),
      fetchedAt: fetchedAt,
    );
  }

  /// Merges this (newer) snapshot over [older]: null metadata falls back to
  /// [older]'s, empty statuses fall back to [older]'s, and each field merges
  /// via [FieldSnapshot.mergedWith] — see there for the value/label rule.
  /// Fields only present in [older] (e.g. a pinned-fields refresh only
  /// recovers the pinned subset) are kept as-is.
  ChannelSnapshot mergedWith(ChannelSnapshot older) {
    final mergedFields = <FieldSnapshot>[];
    final seenIds = <int>{};
    for (final field in fields) {
      final match = older.fields.where((o) => o.id == field.id);
      mergedFields.add(
        match.isEmpty ? field : field.mergedWith(match.first),
      );
      seenIds.add(field.id);
    }
    for (final field in older.fields) {
      if (!seenIds.contains(field.id)) mergedFields.add(field);
    }
    return ChannelSnapshot(
      description: description ?? older.description,
      url: url ?? older.url,
      githubUrl: githubUrl ?? older.githubUrl,
      fields: mergedFields,
      statuses: statuses.isNotEmpty ? statuses : older.statuses,
      fetchedAt: fetchedAt,
    );
  }
}
