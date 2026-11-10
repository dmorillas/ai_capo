/// Chat message model shared by all providers.
library;

import 'package:ai_capo/models/tool.dart';

/// The role of a [ChatMessage] within a conversation.
enum MessageRole {
  /// Instructions that steer the behaviour of the model.
  system,

  /// Input produced by the user.
  user,

  /// Output produced by the model.
  assistant,

  /// The result of a tool call, sent back to the model.
  tool;

  /// Parses [value] into a [MessageRole].
  ///
  /// The comparison is case-insensitive. Unknown values fall back to
  /// [MessageRole.user].
  static MessageRole fromString(String value) {
    return MessageRole.values.firstWhere(
      (r) => r.name == value.toLowerCase(),
      orElse: () => MessageRole.user,
    );
  }
}

/// A single message in a conversation sent to a provider.
///
/// Use the factory constructors ([ChatMessage.system], [ChatMessage.user],
/// [ChatMessage.assistant] and [ChatMessage.tool]) for the most common
/// message shapes.
class ChatMessage {
  /// The role of the author of this message.
  final MessageRole role;

  /// The text content of this message.
  ///
  /// When the role is [MessageRole.tool], the content must be valid JSON
  /// when sending a tool result back to Google Gemini.
  final String content;

  /// An optional name for the author of this message.
  final String? name;

  /// The tool calls requested by the model in an assistant message.
  final List<ToolCall>? toolCalls;

  /// The identifier of the tool call this message responds to.
  ///
  /// Only set on messages with the [MessageRole.tool] role.
  final String? toolCallId;

  /// Creates a message with an explicit [role].
  const ChatMessage({
    required this.role,
    required this.content,
    this.name,
    this.toolCalls,
    this.toolCallId,
  });

  /// Creates a [MessageRole.system] message with [content].
  factory ChatMessage.system(String content) => ChatMessage(role: MessageRole.system, content: content);

  /// Creates a [MessageRole.user] message with [content].
  factory ChatMessage.user(String content) => ChatMessage(role: MessageRole.user, content: content);

  /// Creates an [MessageRole.assistant] message with [content].
  ///
  /// [toolCalls] carries the tool calls requested by the model when replaying
  /// an assistant turn in a tool-calling conversation.
  factory ChatMessage.assistant(String content, {List<ToolCall>? toolCalls}) =>
      ChatMessage(role: MessageRole.assistant, content: content, toolCalls: toolCalls);

  /// Creates a [MessageRole.tool] message with the result of a tool call.
  ///
  /// [toolCallId] must match the `id` of the [ToolCall] being answered and
  /// [content] must contain the tool result.
  factory ChatMessage.tool({required String toolCallId, required String content}) =>
      ChatMessage(role: MessageRole.tool, content: content, toolCallId: toolCallId);
}
