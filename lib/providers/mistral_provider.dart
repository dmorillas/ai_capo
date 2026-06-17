import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/providers/ai_provider.dart';

class MistralProvider implements AIProvider {
  final String _baseUrl = 'https://api.mistral.ai/v1';

  @override
  final String providerName = 'mistral';

  final AIConfig config;
  final http.Client _client;

  MistralProvider({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final key = config.apiKey;
    if (key == null || key.isEmpty) {
      throw const AIConfigurationException(
        'Mistral API key is required.',
        provider: 'mistral',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $key',
    };
  }

  Map<String, dynamic> _body({required List<ChatMessage> messages, required ChatCompletionRequest options}) {
    final body = <String, dynamic>{
      'model': options.model,
      'messages': messages.map((m) => {'role': m.role.name, 'content': m.content}).toList(),
      'max_tokens': options.maxTokens ?? config.defaultMaxTokens,
    };

    if (options.temperature != null) body['temperature'] = options.temperature;
    if (options.topP != null) body['top_p'] = options.topP;
    if (options.seed != null) body['random_seed'] = options.seed;
    if (options.stop != null) body['stop'] = options.stop;
    if (options.responseFormat != null) body['response_format'] = {'type': options.responseFormat};
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
        Uri.parse('$_baseUrl/chat/completions'),
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
    final body = _body(messages: messages, options: options);
    body['stream'] = true;

    try {
      final request = http.Request('POST', Uri.parse('$_baseUrl/chat/completions'))
        ..headers.addAll(_headers())
        ..body = jsonEncode(body);

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
            final choices = json['choices'] as List?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices.first['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String? ?? '';
              final finishReason = choices.first['finish_reason'];

              yield ChatCompletionStreamResponse(
                content: content,
                isComplete: finishReason != null,
                model: json['model'] as String?,
                provider: providerName,
              );

              if (finishReason != null) break;
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
    final choices = (json['choices'] as List<dynamic>)
        .map((c) => ChatCompletionChoice(
      index: (c['index'] as num).toInt(),
      content: c['message']?['content'] as String?,
      finishReason: c['finish_reason'] as String?,
    )).toList();

    return ChatCompletionResponse(
      model: json['model'] as String?,
      provider: providerName,
      choices: choices,
      usage: json['usage'],
      rawResponse: json,
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    _client.close();
  }
}
