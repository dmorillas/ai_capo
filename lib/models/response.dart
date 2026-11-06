import 'package:ai_capo/models/tool.dart';

class ChatCompletionResponse {
  final String? model;
  final String? provider;
  final List<ChatCompletionChoice> choices;
  final Map<String, dynamic>? usage;
  final Map<String, dynamic>? rawResponse;
  final DateTime timestamp;

  const ChatCompletionResponse({
    this.model,
    this.provider,
    required this.choices,
    this.usage,
    this.rawResponse,
    required this.timestamp,
  });
}

class ChatCompletionChoice {
  final int index;
  final String? content;
  final String? finishReason;
  final List<ToolCall>? toolCalls;

  const ChatCompletionChoice({
    required this.index,
    required this.content,
    required this.finishReason,
    this.toolCalls,
  });
}
