import 'dart:async';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';

abstract class AIProvider {
  String get providerName;

  Future<ChatCompletionResponse> chatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options});

  Stream<ChatCompletionStreamResponse> streamChatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options});
}