import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart' hide Tool;
import 'package:firebase_ai/firebase_ai.dart' as firebase show Tool;
import 'package:http/http.dart' as http;
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/models/tool.dart' as ai_capo_tool;
import 'package:ai_capo/providers/ai_provider.dart';

class GoogleProvider implements AIProvider {
  @override
  final String providerName = 'google';

  final AIConfig config;
  final FirebaseAI _firebaseAI;

  GoogleProvider({required this.config, http.Client? client})
    : _firebaseAI = FirebaseAI.agentPlatform();

  GenerationConfig _generationConfig(ChatCompletionRequest options) {
    final format = options.responseFormat;
    return GenerationConfig(
      stopSequences: options.stop,
      maxOutputTokens: options.maxTokens ?? config.defaultMaxTokens,
      temperature: options.temperature,
      topP: options.topP,
      topK: options.topK,
      presencePenalty: options.presencePenalty,
      frequencyPenalty: options.frequencyPenalty,
      responseMimeType: format != null ? 'application/json' : null,
      responseJsonSchema: format != null && format.type == ResponseFormatType.jsonSchema
          ? format.schema
          : null,
    );
  }

  List<firebase.Tool> _firebaseTools(List<ai_capo_tool.Tool> tools) {
    return tools.map((t) {
      final schemaParams = <String, Schema>{};
      if (t.parameters != null) {
        for (final entry in t.parameters!.entries) {
          schemaParams[entry.key] = _buildSchema(entry.value as Map<String, dynamic>);
        }
      }
      return firebase.Tool.functionDeclarations([
        FunctionDeclaration(
          t.name,
          t.description ?? '',
          parameters: schemaParams,
        ),
      ]);
    }).toList();
  }

  Schema _buildSchema(Map<String, dynamic> jsonSchema) {
    final type = jsonSchema['type'] as String? ?? 'object';

    switch (type) {
      case 'object':
        final properties = jsonSchema['properties'] as Map<String, dynamic>?;
        final requiredFields = jsonSchema['required'] as List?;
        final propertySchemas = <String, Schema>{};

        if (properties != null) {
          for (final entry in properties.entries) {
            propertySchemas[entry.key] = _buildSchema(entry.value as Map<String, dynamic>);
          }
        }

        return Schema.object(
          properties: propertySchemas,
          optionalProperties: requiredFields != null
              ? (List<String>.from(
                  (jsonSchema['properties'] as Map<String, dynamic>).keys
                      .where((k) => !requiredFields.contains(k))))
              : null,
          description: jsonSchema['description'] as String?,
        );
      case 'array':
        final items = jsonSchema['items'] as Map<String, dynamic>?;
        return Schema.array(
          items: items != null ? _buildSchema(items) : Schema.string(),
          description: jsonSchema['description'] as String?,
        );
      case 'string':
        final enumValues = jsonSchema['enum'] as List?;
        if (enumValues != null) {
          return Schema.enumString(
            enumValues: enumValues.cast<String>(),
            description: jsonSchema['description'] as String?,
          );
        }
        return Schema.string(description: jsonSchema['description'] as String?);
      case 'number':
        return Schema.number(description: jsonSchema['description'] as String?);
      case 'integer':
        return Schema.integer(description: jsonSchema['description'] as String?);
      case 'boolean':
        return Schema.boolean(description: jsonSchema['description'] as String?);
      default:
        return Schema.string(description: jsonSchema['description'] as String?);
    }
  }

  @override
  Future<ChatCompletionResponse> chatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async {
    final generationConfig = _generationConfig(options);

    final systemMessage = messages.where((message) => message.role == MessageRole.system).firstOrNull?.content;

    final tools = options.tools != null ? _firebaseTools(options.tools!) : null;

    final ai = _firebaseAI.generativeModel(
      model: options.model,
      systemInstruction: systemMessage != null ? Content.system(systemMessage) : null,
      generationConfig: generationConfig,
      tools: tools,
    );

    final conversationMessages = _buildContents(messages);

    try {
      final response = await ai.generateContent(conversationMessages);
      return _parseResponse(options.model, response);
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  @override
  Stream<ChatCompletionStreamResponse> streamChatCompletion({required List<ChatMessage> messages, required ChatCompletionRequest options}) async* {
    final generationConfig = _generationConfig(options);

    final systemMessage = messages.where((message) => message.role == MessageRole.system).firstOrNull?.content;

    final tools = options.tools != null ? _firebaseTools(options.tools!) : null;

    final ai = _firebaseAI.generativeModel(
      model: options.model,
      systemInstruction: systemMessage != null ? Content.system(systemMessage) : null,
      generationConfig: generationConfig,
      tools: tools,
    );

    final conversationMessages = _buildContents(messages);

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

        List<ai_capo_tool.ToolCallDelta>? toolCalls;
        final functionParts = candidate.content.parts.whereType<FunctionCall>().toList();
        if (functionParts.isNotEmpty) {
          toolCalls = functionParts.asMap().entries.map((entry) {
            final jsonMap = entry.value.toJson() as Map<String, dynamic>;
            final thoughtSignature = jsonMap['thoughtSignature'] as String?;

            return ai_capo_tool.ToolCallDelta(
              index: entry.key,
              type: 'function',
              function: ai_capo_tool.FunctionCallResult(
                name: entry.value.name,
                arguments: jsonEncode(entry.value.args),
              ),
              thoughtSignature: thoughtSignature,
            );
          }).toList();
        }

        if (text.isNotEmpty || toolCalls != null) {
          yield ChatCompletionStreamResponse(
            content: text,
            isComplete: isComplete,
            model: options.model,
            provider: providerName,
            toolCalls: toolCalls,
          );
        }

        if (isComplete) break;
      }
    } catch (e) {
      if (e is AIException) rethrow;
      throw AINetworkException(e.toString(), provider: providerName);
    }
  }

  List<Content> _buildContents(List<ChatMessage> messages) {
    final contents = <Content>[];

    for (final message in messages) {
      if (message.role == MessageRole.system) continue;

      if (message.role == MessageRole.tool && message.toolCallId != null) {
        contents.add(Content.functionResponse(
          message.toolCallId!,
          jsonDecode(message.content) as Map<String, dynamic>,
        ));
      } else if (message.role == MessageRole.assistant && message.toolCalls != null && message.toolCalls!.isNotEmpty) {
        final parts = <Part>[];
        if (message.content.isNotEmpty) {
          parts.add(TextPart(message.content));
        }
        for (final tc in message.toolCalls!) {
          if (tc.thoughtSignature != null) {
            parts.add(UnknownPart({
              'functionCall': {
                'name': tc.function.name ?? "",
                'args': jsonDecode(tc.function.arguments ?? "{}") as Map<String, dynamic>
              },
              'thoughtSignature': tc.thoughtSignature,
            }));
          } else {
             parts.add(FunctionCall(tc.function.name ?? "", jsonDecode(tc.function.arguments ?? "{}") as Map<String, dynamic>));
          }
        }
        contents.add(Content('model', parts));
      } else {
        final role = message.role == MessageRole.assistant ? 'model' : 'user';
        contents.add(Content(role, [TextPart(message.content)]));
      }
    }

    return contents;
  }

  ChatCompletionResponse _parseResponse(String model, GenerateContentResponse response) {
    final choices = response.candidates.asMap().entries.map((entry) {
      final idx = entry.key;
      final candidate = entry.value;

      String text = '';
      List<ai_capo_tool.ToolCall>? toolCalls;

      for (final part in candidate.content.parts) {
        if (part is TextPart) {
          text += part.text;
        } else if (part is FunctionCall) {
          toolCalls ??= [];
          final jsonMap = part.toJson() as Map<String, dynamic>;
          final thoughtSignature = jsonMap['thoughtSignature'] as String?;

          toolCalls.add(ai_capo_tool.ToolCall(
            id: part.name,
            type: 'function',
            function: ai_capo_tool.FunctionCallResult(
              name: part.name,
              arguments: jsonEncode(part.args),
            ),
            thoughtSignature: thoughtSignature,
          ));
        }
      }

      return ChatCompletionChoice(
        index: idx,
        content: text.isNotEmpty ? text : null,
        finishReason: candidate.finishReason.toString(),
        toolCalls: toolCalls,
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
}
