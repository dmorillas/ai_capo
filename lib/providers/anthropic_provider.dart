import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/providers/ai_provider.dart';

class AnthropicProvider implements AIProvider {
  final String _baseUrl = 'https://api.anthropic.com/v1';

  @override
  final String providerName = 'anthropic';

  final AIConfig config;
  final http.Client _client;

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
    };
  }

  Map<String, dynamic> _body({required List<ChatMessage> messages, required ChatCompletionRequest options}) {
    final systemMessage = messages.where((m) => m.role == MessageRole.system).toList();
    final conversationMessages = messages.where((m) => m.role != MessageRole.system).toList();

    final body = <String, dynamic>{
      'model': options.model,
      'messages': conversationMessages
          .map((m) => {
        'role': m.role == MessageRole.assistant ? 'assistant' : 'user',
        'content': m.content,
      },
      ).toList(),
      'max_tokens': options.maxTokens ?? config.defaultMaxTokens,
    };

    if (systemMessage.isNotEmpty) {
      body['system'] = [
        {
          "text": systemMessage.first.content,
          "type": "text"
        }
      ];
    }

    if (options.temperature != null) body['temperature'] = options.temperature;
    if (options.topP != null) body['top_p'] = options.topP;
    if (options.topK != null) body['top_k'] = options.topK;
    if (options.stop != null) body['stop_sequences'] = options.stop;
    if (options.customParameters != null) {
      body.addAll(options.customParameters!);
    }

    return body;
  }

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

  @override
  Stream<ChatCompletionStreamResponse> streamChatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async* {
    final body = _body(messages: messages, options: options)
      ..['stream'] = true;

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

      String accumulatedContent = '';

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
            if (json['type'] == 'content_block_delta') {
              final delta = json['delta'] as Map<String, dynamic>?;
              final text = delta?['text'] as String? ?? '';
              accumulatedContent += text;
              yield ChatCompletionStreamResponse(
                content: text,
                isComplete: false,
                model: json['model'] as String?,
                provider: providerName,
              );
            } else if (json['type'] == 'message_stop') {
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

    if (content != null) {
      for (final block in content) {
        if (block['type'] == 'text') {
          text += block['text'] as String? ?? '';
        }
      }
    }

    return ChatCompletionResponse(
      model: json['model'] as String?,
      provider: providerName,
      choices: [
        ChatCompletionChoice(
          index: 0,
          content: text,
          finishReason: json['stop_reason'] as String?,
        ),
      ],
      usage: json['usage'],
      rawResponse: json,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    _client.close();
  }
}
