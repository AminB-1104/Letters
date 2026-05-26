import '../../social/models/user_summary.dart';

class MessagePreview {
  final String id;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;

  const MessagePreview({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  factory MessagePreview.fromJson(Map<String, dynamic> json) {
    return MessagePreview(
      id: json['id'] as String,
      senderId: json['sender'] as String? ?? '',
      content: json['content'] as String? ?? '',
      type: json['type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Chat {
  final String id;
  final UserSummary other;
  final MessagePreview? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Chat({
    required this.id,
    required this.other,
    required this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
  });

  Chat copyWith({MessagePreview? lastMessage, DateTime? updatedAt}) {
    return Chat(
      id: id,
      other: other,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Chat.fromJson(Map<String, dynamic> json) {
    final other = json['other'] as Map<String, dynamic>?;
    final last = json['lastMessage'] as Map<String, dynamic>?;
    return Chat(
      id: json['id'] as String,
      other: other != null
          ? UserSummary.fromJson(other)
          : const UserSummary(
              id: '',
              username: '',
              displayName: 'Unknown',
            ),
      lastMessage: last != null ? MessagePreview.fromJson(last) : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
