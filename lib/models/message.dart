enum MessageRole {
  system,
  user,
  assistant;

  static MessageRole fromString(String value) {
    return MessageRole.values.firstWhere(
          (r) => r.name == value.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}

class ChatMessage {
  final MessageRole role;
  final String content;
  final String? name;

  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
  });

  factory ChatMessage.system(String content) => ChatMessage(role: MessageRole.system, content: content);

  factory ChatMessage.user(String content) => ChatMessage(role: MessageRole.user, content: content);

  factory ChatMessage.assistant(String content) => ChatMessage(role: MessageRole.assistant, content: content);

  Map<String, dynamic> toJson() {
    return {
      'role': role.name,
      'content': content,
      if (name != null) 'name': name,
    };
  }
}
