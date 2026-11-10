/// The Anthropic Claude implementation of [AIProvider].
library;

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/models/tool.dart';
import 'package:ai_capo/providers/ai_provider.dart';

/// The [AIProvider] implementation for Anthropic Claude.
///
/// Requests are sent to `https://api.anthropic.com/v1/messages` using
/// [AIConfig.apiKey] and [AIConfig.providerVersion] (the required
/// `anthropic-version` header). System messages are translated to the
/// Anthropic `system` parameter, and tool results to `tool_result` blocks.
///
/// Anthropic does not support schema-less JSON output: requesting
/// [ResponseFormatType.jsonObject] throws an [AIModelNotSupportedException].
class AnthropicProvider implements AIProvider {
  final String _baseUrl = 'https://api.anthropic.com/v1';

  /// The name of this provider (`anthropic`).
  @override
  final String providerName = 'anthropic';

  /// The configuration (API key, version, timeout, defaults) used by this
  /// provider.
  final AIConfig config;
  final http.Client _client;

  /// Creates an Anthropic provider with the given [config].
  ///
  /// An optional HTTP [client] can be injected, for example in tests.
  AnthropicProvider({required this.config, http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> _headers() {
    if (config.apiKey == null || config.apiKey!.isEmpty) {
      throw const AIConfigurationException(
        'Anthropic API key is required.',
        provider: 'anthropic',
      );
    }

    if (config.providerVersion == null || config.providerVersion!.isEmpty) {
      throw const AIConfigurationException(
        'Anthropic version is required.',
        provider: 'anthropic',
      );
    }

    return {
      'Content-Type': 'application/json',
      'X-Api-Key': config.apiKey!,
      'anthropic-version': config.providerVersion!,
      'anthropic-dangerous-direct-browser-access': 'true',
    };
  }

  List<Map<String, dynamic>> _tools(List<Tool> tools) {
    return tools.map((t) => {
            'name': t.name,
            if (t.description != null) 'description': t.description,
            if (t.parameters != null)
              'input_schema': {
                'type': 'object',
                'properties': t.parameters,
                if (t.required != null && t.required!.isNotEmpty) 'required': t.required,
              },
          },
        )
        .toList();
  }

  Map<String, dynamic>? _toolChoice(ToolChoice choice) {
    return switch (choice) {
      ToolChoiceAuto() => {'type': 'auto'},
      ToolChoiceNone() => {'type': 'none'},
      ToolChoiceRequired() => {'type': 'any'},
      ToolChoiceFunction(:final name) => {'type': 'tool', 'name': name},
    };
  }

  List<Map<String, dynamic>> _messages(List<ChatMessage> messages) {
    final result = <Map<String, dynamic>>[];

    for (final message in messages) {
      if (message.role == MessageRole.system) continue;

      if (message.role == MessageRole.tool) {
        result.add({
          'role': 'user',
          'content': [
            {
              'type': 'tool_result',
              'tool_use_id': message.toolCallId,
              'content': message.content,
            },
          ],
        });
      } else if (message.role == MessageRole.assistant && message.toolCalls != null && message.toolCalls!.isNotEmpty) {
        final content = <Map<String, dynamic>>[];
        if (message.content.isNotEmpty) {
          content.add({'type': 'text', 'text': message.content});
        }
        for (final tc in message.toolCalls!) {
          content.add({
            'type': 'tool_use',
            'id': tc.id,
            'name': tc.function.name,
            'input': jsonDecode(tc.function.arguments ?? "{}"),
          });
        }
        result.add({'role': 'assistant', 'content': content});
      } else {
        result.add({
          'role': message.role == MessageRole.assistant ? 'assistant' : 'user',
          'content': message.content,
        });
      }
    }

    return result;
  }

  Map<String, dynamic> _body({required List<ChatMessage> messages, required ChatCompletionRequest options}) {
    final systemMessage = messages.where((m) => m.role == MessageRole.system).toList();
    final conversationMessages = messages.where((m) => m.role != MessageRole.system).toList();

    final body = <String, dynamic>{
      'model': options.model,
      'messages': _messages(conversationMessages),
      'max_tokens': options.maxTokens ?? config.defaultMaxTokens,
    };

    if (systemMessage.isNotEmpty) {
      body['system'] = [
        {"text": systemMessage.first.content, "type": "text"},
      ];
    }

    if (options.temperature != null) body['temperature'] = options.temperature;
    if (options.topP != null) body['top_p'] = options.topP;
    if (options.topK != null) body['top_k'] = options.topK;
    if (options.stop != null) body['stop_sequences'] = options.stop;
    if (options.tools != null && options.tools!.isNotEmpty) {
      body['tools'] = _tools(options.tools!);
    }
    if (options.toolChoice != null) {
      body['tool_choice'] = _toolChoice(options.toolChoice!);
    }
    if (options.responseFormat != null) {
      final format = options.responseFormat!;
      switch (format.type) {
        case ResponseFormatType.jsonObject:
          throw const AIModelNotSupportedException(
            'Anthropic structured output requires a JSON schema. '
            'Use ResponseFormatType.jsonSchema instead.',
            provider: 'anthropic',
          );
        case ResponseFormatType.jsonSchema:
          body['output_config'] = {
            'format': {'type': 'json_schema', 'schema': format.schema},
          };
      }
    }
    if (options.customParameters != null) {
      body.addAll(options.customParameters!);
    }

    return body;
  }

  /// Sends [messages] to Anthropic and returns the complete response.
  @override
  Future<ChatCompletionResponse> chatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async {
    final body = _body(messages: messages, options: options);

    try {
      final response = await _client.post(
            Uri.parse('$_baseUrl/messages'),
            headers: _headers(),
            body: jsonEncode(body),
          ).timeout(config.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseResponse(json);
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw AIAuthenticationException(
          'Authentication failed',
          provider: providerName,
          statusCode: response.statusCode,
        );
      } else if (response.statusCode == 429) {
        throw AIRateLimitException(
          'Rate limit exceeded',
          provider: providerName,
          statusCode: response.statusCode,
        );
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        throw AIException(
          error?['error']?['message'] ?? 'Request failed',
          provider: providerName,
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  /// Sends [messages] to Anthropic and streams the response as it is
  /// generated.
  @override
  Stream<ChatCompletionStreamResponse> streamChatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async* {
    final body = _body(messages: messages, options: options)..['stream'] = true;

    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/messages'));
      request.headers.addAll(_headers());
      request.body = jsonEncode(body);

      final streamedResponse = await _client
          .send(request)
          .timeout(config.timeout);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw AIException(
          'Stream request failed: $errorBody',
          provider: providerName,
          statusCode: streamedResponse.statusCode,
        );
      }

      String? currentToolId;
      String? currentToolName;
      final accumulatedToolArgs = StringBuffer();

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty || !line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data == '[DONE]') {
            yield ChatCompletionStreamResponse(
              content: '',
              isComplete: true,
              provider: providerName,
            );
            break;
          }

          try {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String?;

            if (type == 'content_block_start') {
              final block = json['content_block'] as Map<String, dynamic>?;
              if (block?['type'] == 'tool_use') {
                currentToolId = block?['id'] as String?;
                currentToolName = block?['name'] as String?;
                accumulatedToolArgs.clear();
              }
            } else if (type == 'content_block_delta') {
              final delta = json['delta'] as Map<String, dynamic>?;
              if (delta?['type'] == 'text_delta') {
                final text = delta?['text'] as String? ?? '';
                yield ChatCompletionStreamResponse(
                  content: text,
                  isComplete: false,
                  model: json['model'] as String?,
                  provider: providerName,
                );
              } else if (delta?['type'] == 'input_json_delta') {
                final partial = delta?['partial_json'] as String? ?? '';
                accumulatedToolArgs.write(partial);
              }
            } else if (type == 'content_block_stop') {
              if (currentToolId != null && currentToolName != null) {
                yield ChatCompletionStreamResponse(
                  content: '',
                  isComplete: false,
                  model: json['model'] as String?,
                  provider: providerName,
                  toolCalls: [
                    ToolCallDelta(
                      index: 0,
                      id: currentToolId,
                      type: 'function',
                      function: FunctionCallResult(
                        name: currentToolName,
                        arguments: accumulatedToolArgs.toString(),
                      ),
                    ),
                  ],
                );
                currentToolId = null;
                currentToolName = null;
                accumulatedToolArgs.clear();
              }
            } else if (type == 'message_stop') {
              yield ChatCompletionStreamResponse(
                content: '',
                isComplete: true,
                provider: providerName,
              );
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  ChatCompletionResponse _parseResponse(Map<String, dynamic> json) {
    final content = json['content'] as List?;
    String text = '';
    List<ToolCall>? toolCalls;

    if (content != null) {
      for (final block in content) {
        if (block['type'] == 'text') {
          text += block['text'] as String? ?? '';
        } else if (block['type'] == 'tool_use') {
          toolCalls ??= [];
          toolCalls.add(
            ToolCall(
              id: block['id'] as String? ?? '',
              type: 'function',
              function: FunctionCallResult(
                name: block['name'] as String? ?? '',
                arguments: jsonEncode(block['input']),
              ),
            ),
          );
        }
      }
    }

    return ChatCompletionResponse(
      model: json['model'] as String?,
      provider: providerName,
      choices: [
        ChatCompletionChoice(
          index: 0,
          content: text.isNotEmpty ? text : null,
          finishReason: json['stop_reason'] as String?,
          toolCalls: toolCalls,
        ),
      ],
      usage: json['usage'],
      rawResponse: json,
      timestamp: DateTime.now(),
    );
  }

  /// Closes the underlying HTTP client and releases its resources.
  void dispose() {
    _client.close();
  }
}
