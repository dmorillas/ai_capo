import 'dart:convert';

import 'package:ai_capo/exceptions/exceptions.dart';

class ChatCompletionStreamResponse {
  final String content;
  final bool isComplete;
  final String? model;
  final String? provider;
  final Map<String, dynamic>? rawResponse;

  const ChatCompletionStreamResponse({
    required this.content,
    required this.isComplete,
    this.model,
    this.provider,
    this.rawResponse,
  });

  factory ChatCompletionStreamResponse.fromJson(Map<String, dynamic> json, {String? provider}) {
    String content = '';
    bool isComplete = false;

    if (json.containsKey('choices') && json['choices'] is List) {
      final choice = (json['choices'] as List).first;
      content = choice['delta']?['content'] as String? ?? '';
      final finishReason = choice['finish_reason'];
      isComplete = finishReason != null && finishReason != 'length';
    } else if (json.containsKey('candidates')) {
      final candidate = (json['candidates'] as List?)?.first;
      content = candidate?['content']?['parts']?[0]?['text'] as String? ?? '';
      isComplete =
          json['candidates'] != null &&
          (json['candidates'] as List).isNotEmpty &&
          candidate?['finishReason'] != null;
    } else if (json.containsKey('delta')) {
      content =
          json['delta']?['content'] as String? ??
          json['content'] as String? ??
          '';
      isComplete = json['done'] == true || json['finish_reason'] != null;
    } else if (json.containsKey('error')) {
      throw AIException(
        json['error']?['message'] ?? 'Unknown streaming error',
        provider: provider,
      );
    }

    return ChatCompletionStreamResponse(
      content: content,
      isComplete: isComplete,
      model: json['model'] as String?,
      provider: provider,
      rawResponse: json,
    );
  }

  factory ChatCompletionStreamResponse.parseSseLine(String line, {String? provider}) {
    if (line.startsWith('data:')) {
      final data = line.substring(5).trim();
      if (data == '[DONE]') {
        return ChatCompletionStreamResponse(
          content: '',
          isComplete: true,
          provider: provider,
        );
      }
      try {
        final json = jsonDecode(data) as Map<String, dynamic>;
        return ChatCompletionStreamResponse.fromJson(json, provider: provider);
      } catch (_) {
        return ChatCompletionStreamResponse(
          content: '',
          isComplete: false,
          provider: provider,
        );
      }
    }
    return ChatCompletionStreamResponse(content: '', isComplete: false, provider: provider);
  }
}
