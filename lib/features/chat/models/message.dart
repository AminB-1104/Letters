class Message {
  final String id;
  final String chatId;
  final String senderId;
  final String content;
  final String type;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.content,
    required this.type,
    required this.createdAt,
  });

  bool isMine(String? currentUserId) =>
      currentUserId != null && senderId == currentUserId;

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as String,
      chatId: json['chatId'] as String,
      senderId: json['sender'] as String,
      content: json['content'] as String,
      type: json['type'] as String? ?? 'text',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
