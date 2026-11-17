import 'dart:convert';

import 'channel_settings.dart';

class Channel {
  final int id;
  final String serverUrl;
  final bool isPublic;
  final String? apiKey;
  final String? name;
  final String? description;
  final String? url;
  final String? githubUrl;
  final DateTime? updatedAt;
  final int fieldCount;
  final bool authError;
  final ChannelSettings settings;

  const Channel({
    required this.id,
    required this.serverUrl,
    required this.isPublic,
    this.apiKey,
    this.name,
    this.description,
    this.url,
    this.githubUrl,
    this.updatedAt,
    this.fieldCount = 0,
    this.authError = false,
    this.settings = ChannelSettings.defaults,
  });

  String get displayName => name?.isNotEmpty == true ? name! : 'Channel $id';

  Channel copyWith({
    int? id,
    String? serverUrl,
    bool? isPublic,
    String? apiKey,
    String? name,
    String? description,
    String? url,
    String? githubUrl,
    DateTime? updatedAt,
    int? fieldCount,
    bool? authError,
    ChannelSettings? settings,
  }) {
    return Channel(
      id: id ?? this.id,
      serverUrl: serverUrl ?? this.serverUrl,
      isPublic: isPublic ?? this.isPublic,
      apiKey: apiKey ?? this.apiKey,
      name: name ?? this.name,
      description: description ?? this.description,
      url: url ?? this.url,
      githubUrl: githubUrl ?? this.githubUrl,
      updatedAt: updatedAt ?? this.updatedAt,
      fieldCount: fieldCount ?? this.fieldCount,
      authError: authError ?? this.authError,
      settings: settings ?? this.settings,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'serverUrl': serverUrl,
    'isPublic': isPublic,
    if (apiKey != null) 'apiKey': apiKey,
    if (name != null) 'name': name,
    if (authError) 'authError': authError,
    if (!settings.isDefault) 'settings': settings.toJson(),
  };

  factory Channel.fromJson(Map<String, dynamic> json) => Channel(
    id: json['id'] as int,
    serverUrl: json['serverUrl'] as String,
    isPublic: json['isPublic'] as bool,
    apiKey: json['apiKey'] as String?,
    name: json['name'] as String?,
    authError: json['authError'] as bool? ?? false,
    settings: json['settings'] is Map<String, dynamic>
        ? ChannelSettings.fromJson(json['settings'] as Map<String, dynamic>)
        : ChannelSettings.defaults,
  );

  static List<Channel> listFromJson(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => Channel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJson(List<Channel> channels) =>
      jsonEncode(channels.map((c) => c.toJson()).toList());

  @override
  bool operator ==(Object other) =>
      other is Channel && id == other.id && serverUrl == other.serverUrl;

  @override
  int get hashCode => Object.hash(id, serverUrl);
}
