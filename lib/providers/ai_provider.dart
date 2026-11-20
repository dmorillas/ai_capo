/// The abstraction implemented by every AI provider.
library;

import 'dart:async';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';

/// The contract implemented by all providers supported by AI Capo.
///
/// Implementations translate the normalized [ChatCompletionRequest] and
/// [ChatMessage] models into their own wire format and normalize the
/// responses back, so that the same code works with every provider.
abstract class AIProvider {
  /// Const constructor so that subclasses can define `const` constructors.
  const AIProvider();

  /// The name of this provider, for example `openai` or `google`.
  String get providerName;

  /// Sends [messages] to the model and returns the complete response.
  ///
  /// Throws an [AIException] subclass when the request fails.
  Future<ChatCompletionResponse> chatCompletion({
    required List<ChatMessage> messages,
    required ChatCompletionRequest options,
  });

  /// Sends [messages] to the model and streams the response as it is
  /// generated.
  ///
  /// Throws an [AIException] subclass when the request fails.
  Stream<ChatCompletionStreamResponse> streamChatCompletion({
    required List<ChatMessage> messages,
    required ChatCompletionRequest options,
  });
}
