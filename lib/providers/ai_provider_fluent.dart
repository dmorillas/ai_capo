import 'dart:async';

import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/models/tool.dart';
import 'package:ai_capo/providers/ai_provider.dart';

/// Adds fluent chat request construction to an [AIProvider].
extension AIProviderFluent on AIProvider {
  /// Starts a chat request using the supplied generation [options].
  ChatCompletionBuilder chat({required ChatCompletionRequest options}) {
    return ChatCompletionBuilder._(this, options);
  }
}

/// A reusable builder that immutably accumulates chat messages.
///
/// Generation options are retained and delegated as supplied. Mutable
/// collections contained by them are not copied.
final class ChatCompletionBuilder {
  ChatCompletionBuilder._(
    this._provider,
    this._options, [
    Iterable<ChatMessage> messages = const <ChatMessage>[],
  ]) : _messages = List<ChatMessage>.unmodifiable(messages);

  final AIProvider _provider;
  final ChatCompletionRequest _options;
  final List<ChatMessage> _messages;

  /// Appends a system message to the request.
  ChatCompletionBuilder withSystemMessage(String content) {
    return _append([ChatMessage.system(content)]);
  }

  /// Appends each string as a user message.
  ChatCompletionBuilder withMessages(Iterable<String> messages) {
    return _append(messages.map((content) => ChatMessage.user(content)));
  }

  /// Appends an assistant message, optionally carrying [toolCalls].
  ChatCompletionBuilder withAssistantMessage(
    String content, {
    List<ToolCall>? toolCalls,
  }) {
    return _append([ChatMessage.assistant(content, toolCalls: toolCalls)]);
  }

  /// Appends the result of the tool call identified by [toolCallId].
  ChatCompletionBuilder withToolResult({ required String toolCallId, required String content }) {
    return _append([ChatMessage.tool(toolCallId: toolCallId, content: content)]);
  }

  /// Appends typed messages without changing their roles or names.
  ChatCompletionBuilder withChatMessages(Iterable<ChatMessage> messages) {
    return _append(messages);
  }

  /// Executes the request and returns the complete provider response.
  Future<ChatCompletionResponse> complete() {
    return _provider.chatCompletion(
      messages: List<ChatMessage>.of(_messages),
      options: _options,
    );
  }

  /// Executes the request and returns the provider response stream.
  Stream<ChatCompletionStreamResponse> stream() {
    return _provider.streamChatCompletion(
      messages: List<ChatMessage>.of(_messages),
      options: _options,
    );
  }

  ChatCompletionBuilder _append(Iterable<ChatMessage> messages) {
    return ChatCompletionBuilder._(_provider, _options, [
      ..._messages,
      ...messages,
    ]);
  }
}
