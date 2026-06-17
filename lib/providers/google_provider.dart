import 'package:firebase_ai/firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/providers/ai_provider.dart';

class GoogleProvider implements AIProvider {
  @override
  final String providerName = 'google';

  final AIConfig config;
  final http.Client _client;
  final FirebaseAI _firebaseAI;

  GoogleProvider({required this.config, http.Client? client})
    : _client = client ?? http.Client(),
      _firebaseAI = FirebaseAI.vertexAI(location: "global");

  @override
  Future<ChatCompletionResponse> chatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async {
    final generationConfig = GenerationConfig(
      stopSequences: options.stop,
      maxOutputTokens: options.maxTokens ?? config.defaultMaxTokens,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      presencePenalty: options.presencePenalty,
      frequencyPenalty: options.frequencyPenalty,
    );

    final systemMessage = messages.where((message) => message.role == MessageRole.system).firstOrNull?.content;
    final ai = _firebaseAI.generativeModel(
      model: options.model,
      systemInstruction: systemMessage != null ? Content.system(systemMessage) : null,
      generationConfig: generationConfig
    );

    final conversationMessages = messages.where((message) => message.role != MessageRole.system)
        .map((message) => Content(message.role == MessageRole.assistant ? 'model' : 'user', [TextPart(message.content)]))
        .toList();

    try {
      final response = await ai.generateContent(conversationMessages);
      if (response.text != null) {
        return _parseResponse(options.model, response);
      } else {
        throw AIException(
          'Request failed',
          provider: providerName,
        );
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }

  }

  @override
  Stream<ChatCompletionStreamResponse> streamChatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async* {
    final generationConfig = GenerationConfig(
      stopSequences: options.stop,
      maxOutputTokens: options.maxTokens ?? config.defaultMaxTokens,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      presencePenalty: options.presencePenalty,
      frequencyPenalty: options.frequencyPenalty,
    );

    final systemMessage = messages.where((message) => message.role == MessageRole.system).firstOrNull?.content;
    final ai = _firebaseAI.generativeModel(
        model: options.model,
        systemInstruction: systemMessage != null ? Content.system(systemMessage) : null,
        generationConfig: generationConfig
    );

    final conversationMessages = messages.where((message) => message.role != MessageRole.system)
        .map((message) => Content(message.role == MessageRole.assistant ? 'model' : 'user', [TextPart(message.content)]))
        .toList();

    try {
      final stream = ai.generateContentStream(conversationMessages);

      await for (final response in stream) {
        if (response.candidates.isEmpty) continue;

        final candidate = response.candidates.first;
        final text = candidate.content.parts
            .whereType<TextPart>()
            .map((p) => p.text)
            .join();
        final isComplete = candidate.finishReason != null;

        if (text.isNotEmpty) {
          yield ChatCompletionStreamResponse(
            content: text,
            isComplete: isComplete,
            model: options.model,
            provider: providerName,
          );
        }

        if (isComplete) break;
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  ChatCompletionResponse _parseResponse(String model, GenerateContentResponse response) {
    final choices = response.candidates.asMap().entries.map((entry) {
      final idx = entry.key;
      final candidate = entry.value;
      final text = candidate.content.parts
          .map((part) => (part as TextPart).text)
          .join();

      return ChatCompletionChoice(
        index: idx,
        content: text,
        finishReason: candidate.finishReason.toString(),
      );
    }).toList();

    return ChatCompletionResponse(
      model: model,
      provider: providerName,
      choices: choices,
      usage: {
        "totalTokenCount": response.usageMetadata?.totalTokenCount ?? 0,
        "promptTokenCount": response.usageMetadata?.promptTokenCount ?? 0,
        "candidatesTokenCount": response.usageMetadata?.candidatesTokenCount ?? 0
      },
      timestamp: DateTime.now(),
    );
  }

  void dispose() {
    _client.close();
  }
}
