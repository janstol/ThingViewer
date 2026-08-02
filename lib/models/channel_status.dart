class ChannelStatus {
  final DateTime createdAt;
  final String message;

  const ChannelStatus({required this.createdAt, required this.message});

  Map<String, dynamic> toJson() => {
    'createdAt': createdAt.toIso8601String(),
    'message': message,
  };

  static ChannelStatus? fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final message = json['message'] as String?;
    if (createdAt == null || message == null) return null;
    return ChannelStatus(createdAt: createdAt, message: message);
  }
}
