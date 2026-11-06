import 'dart:convert';

import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/tool.dart';

class ChatCompletionStreamResponse {
  final String content;
  final bool isComplete;
  final String? model;
  final String? provider;
  final List<ToolCallDelta>? toolCalls;
  final Map<String, dynamic>? rawResponse;

  const ChatCompletionStreamResponse({
    required this.content,
    required this.isComplete,
    this.model,
    this.provider,
    this.toolCalls,
    this.rawResponse,
  });

  factory ChatCompletionStreamResponse.fromJson(Map<String, dynamic> json, {String? provider}) {
    String content = '';
    bool isComplete = false;
    List<ToolCallDelta>? toolCalls;

    if (json.containsKey('choices') && json['choices'] is List) {
      final choice = (json['choices'] as List).first;
      content = choice['delta']?['content'] as String? ?? '';
      final finishReason = choice['finish_reason'];
      isComplete = finishReason != null && finishReason != 'length';

      final rawToolCalls = choice['delta']?['tool_calls'] as List?;
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        toolCalls = rawToolCalls.cast<Map<String, dynamic>>().map((tc) {
          final fn = tc['function'] as Map<String, dynamic>? ?? {};
          return ToolCallDelta(
              index: tc['index'] as int? ?? 0,
              id: tc['id'] as String?,
              type: tc['type'] as String? ?? 'function',
              function: FunctionCallResult(
                name: fn['name'] as String? ?? '',
                arguments: fn['arguments'] as String? ?? '{}',
              )
          );
        }).toList();
      }
    } else if (json.containsKey('candidates')) {
      final candidate = (json['candidates'] as List?)?.first;
      content = candidate?['content']?['parts']?[0]?['text'] as String? ?? '';
      isComplete =
          json['candidates'] != null &&
          (json['candidates'] as List).isNotEmpty &&
          candidate?['finishReason'] != null;

      final parts = candidate?['content']?['parts'] as List?;
      if (parts != null) {
        final functionCalls = <ToolCallDelta>[];
        for (var i = 0; i < parts.length; i++) {
          final part = parts[i];
          if (part['functionCall'] != null) {
            final fc = part['functionCall'] as Map<String, dynamic>;
            functionCalls.add(ToolCallDelta(
              index: i,
              type: 'function',
              function: FunctionCallResult(
                name: fc['name'] as String?,
                arguments: fc['args'] != null ? jsonEncode(fc['args']) : null,
              ),
            ));
          }
        }
        if (functionCalls.isNotEmpty) {
          toolCalls = functionCalls;
        }
      }
    } else if (json.containsKey('delta') || json.containsKey('message')) {
      content =
          json['delta']?['content'] as String? ??
          json['message']?['content'] as String? ??
          json['content'] as String? ??
          '';
      isComplete = json['done'] == true || json['finish_reason'] != null;

      final rawToolCalls = json['delta']?['tool_calls'] as List? ?? json['message']?['tool_calls'] as List?;
      if (rawToolCalls != null && rawToolCalls.isNotEmpty) {
        toolCalls = rawToolCalls.cast<Map<String, dynamic>>().map((tc) {
          final fn = tc['function'] as Map<String, dynamic>? ?? {};
          return ToolCallDelta(
              index: tc['index'] as int? ?? 0,
              id: tc['id'] as String?,
              type: tc['type'] as String? ?? 'function',
              function: FunctionCallResult(
                name: fn['name'] as String? ?? '',
                arguments: fn['arguments'] as String? ?? '{}',
              )
          );
        }).toList();
      }
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
      toolCalls: toolCalls,
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
