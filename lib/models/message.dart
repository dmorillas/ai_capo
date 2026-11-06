import 'package:ai_capo/models/tool.dart';

enum MessageRole {
  system,
  user,
  assistant,
  tool;

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
  final List<ToolCall>? toolCalls;
  final String? toolCallId;

  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCalls,
    this.toolCallId,
  });

  factory ChatMessage.system(String content) => ChatMessage(role: MessageRole.system, content: content);

  factory ChatMessage.user(String content) => ChatMessage(role: MessageRole.user, content: content);

  factory ChatMessage.assistant(String content, {List<ToolCall>? toolCalls}) =>
      ChatMessage(role: MessageRole.assistant, content: content, toolCalls: toolCalls);

  factory ChatMessage.tool({required String toolCallId, required String content}) =>
      ChatMessage(role: MessageRole.tool, content: content, toolCallId: toolCallId);
}
