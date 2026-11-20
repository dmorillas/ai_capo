/// Response model for chat completions.
library;

import 'package:ai_capo/models/tool.dart';

/// The normalized result of a chat completion request.
///
/// The response contains one [ChatCompletionChoice] per generated
/// alternative, plus optional usage information and the raw provider payload.
class ChatCompletionResponse {
  /// The model that produced the response, as reported by the provider.
  final String? model;

  /// The name of the provider that produced the response.
  final String? provider;

  /// The generated alternatives, usually a single one.
  final List<ChatCompletionChoice> choices;

  /// Token usage information, in the format returned by the provider.
  final Map<String, dynamic>? usage;

  /// The raw response body received from the provider.
  final Map<String, dynamic>? rawResponse;

  /// When the response was received.
  final DateTime timestamp;

  /// Creates a normalized chat completion response.
  const ChatCompletionResponse({
    this.model,
    this.provider,
    required this.choices,
    this.usage,
    this.rawResponse,
    required this.timestamp,
  });
}

/// A single generated alternative within a [ChatCompletionResponse].
class ChatCompletionChoice {
  /// The index of this choice among the generated alternatives.
  final int index;

  /// The generated text, or `null` when the model only called tools.
  final String? content;

  /// Why generation stopped, as reported by the provider (e.g. `stop`).
  final String? finishReason;

  /// The tool calls requested by the model, if any.
  final List<ToolCall>? toolCalls;

  /// Creates a single generated alternative.
  const ChatCompletionChoice({
    required this.index,
    required this.content,
    required this.finishReason,
    this.toolCalls,
  });
}
