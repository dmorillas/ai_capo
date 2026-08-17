import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/providers/ai_provider.dart';

class OllamaProvider implements AIProvider {
  @override
  final String providerName = 'ollama';

  final AIConfig config;
  final http.Client _client;

  OllamaProvider({required this.config, http.Client? client})
      : _client = client ?? http.Client();

  String get _baseUrl => config.ollamaBaseUrl ?? 'http://localhost:11434';

  Map<String, dynamic> _body({required List<ChatMessage> messages, required ChatCompletionRequest options}) {
    final body = <String, dynamic>{
      'model': options.model,
      'messages': messages.map((m) => {'role': m.role.name, 'content': m.content}).toList(),
      'stream': false,
    };

    body['options'] ??= {};
    if (options.temperature != null) body['options']['temperature'] = options.temperature;
    if (options.maxTokens != null) body['options']['num_predict'] = options.maxTokens;
    if (options.topP != null) body['options']['top_p'] = options.topP;
    if (options.topK != null) body['options']['top_k'] = options.topK;
    if (options.stop != null) body['options']['stop'] = options.stop;
    if (options.seed != null) body['options']['seed'] = options.seed;
    if (options.responseFormat != null) {
      final format = options.responseFormat!;
      body['format'] = switch (format.type) {
        ResponseFormatType.jsonObject => 'json',
        ResponseFormatType.jsonSchema => format.schema,
      };
    }
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
        Uri.parse('$_baseUrl/api/chat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      ).timeout(config.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return _parseResponse(json);
      } else {
        final error = jsonDecode(response.body) as Map<String, dynamic>?;
        throw AIException(
          error?['error'] ?? 'Request failed',
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
      final request = http.Request('POST', Uri.parse('$_baseUrl/api/chat'))
        ..headers.addAll({
          'Content-Type': 'application/json',
        })
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
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            final message = json['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String? ?? '';
            final done = json['done'] == true;

            yield ChatCompletionStreamResponse(
              content: content,
              isComplete: done,
              model: json['model'] as String?,
              provider: providerName,
            );

            if (done) break;
          } catch (_) {}
        }
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  ChatCompletionResponse _parseResponse(Map<String, dynamic> json) {
    final message = json['message'] as Map<String, dynamic>?;
    final int promptTokens = json['prompt_eval_count'] as int? ?? 0;
    final int completionTokens = json['eval_count'] as int? ?? 0;

    return ChatCompletionResponse(
      model: json['model'] as String?,
      provider: providerName,
      choices: [
        ChatCompletionChoice(
          index: 0,
          content: message?['content'] as String?,
          finishReason: json['done'] == true ? 'stop' : 'unknown',
        ),
      ],
      usage: {
        "promptTokens": promptTokens,
        "completionTokens": completionTokens,
        "totalTokens": promptTokens + completionTokens,
      },
      rawResponse: json,
      timestamp: DateTime.now(),
    );
  }

  Future<List<String>> listAvailableModels() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/api/tags'))
          .timeout(config.timeout);

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final models = json['models'] as List?;
        return models?.map((m) => m['name'] as String).toList() ?? [];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _client.close();
  }
}
