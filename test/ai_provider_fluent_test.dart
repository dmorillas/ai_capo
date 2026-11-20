import 'dart:async';

import 'package:ai_capo/ai_capo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AIProviderFluent', () {
    late ChatCompletionResponse completionResponse;
    late _FakeAIProvider provider;

    setUp(() {
      completionResponse = ChatCompletionResponse(
        choices: const [
          ChatCompletionChoice(
            index: 0,
            content: 'Completed',
            finishReason: 'stop',
          ),
        ],
        timestamp: DateTime.utc(2026),
      );
      provider = _FakeAIProvider(
        completionResponse: completionResponse,
        streamResponses: const [
          ChatCompletionStreamResponse(content: 'Streamed', isComplete: false),
          ChatCompletionStreamResponse(content: '', isComplete: true),
        ],
      );
    });

    test('builds user and system messages in order', () async {
      const options = ChatCompletionRequest(
        model: 'test-model',
        temperature: 0.7,
      );

      final response = await provider
          .chat(options: options)
          .withSystemMessage('Be concise.')
          .withMessages(['First question', 'Second question'])
          .complete();

      expect(response, same(completionResponse));
      expect(provider.completionCalls, hasLength(1));

      final call = provider.completionCalls.single;
      expect(call.options, same(options));
      expect(call.messages.map((message) => message.role), [
        MessageRole.system,
        MessageRole.user,
        MessageRole.user,
      ]);
      expect(call.messages.map((message) => message.content), [
        'Be concise.',
        'First question',
        'Second question',
      ]);
    });

    test('preserves typed messages', () async {
      const namedMessage = ChatMessage(
        role: MessageRole.assistant,
        content: 'Previous answer',
        name: 'assistant_name',
      );

      await provider
          .chat(options: const ChatCompletionRequest(model: 'test-model'))
          .withChatMessages([namedMessage])
          .complete();

      final message = provider.completionCalls.single.messages.single;
      expect(message, same(namedMessage));
      expect(message.role, MessageRole.assistant);
      expect(message.name, 'assistant_name');
    });

    test('appends assistant and tool messages with their metadata', () async {
      const toolCalls = [
        ToolCall(
          id: 'call_1',
          function: FunctionCallResult(
            name: 'get_weather',
            arguments: '{"location":"Paris"}',
          ),
        ),
      ];

      await provider
          .chat(options: const ChatCompletionRequest(model: 'test-model'))
          .withMessages(['What is the weather?'])
          .withAssistantMessage('', toolCalls: toolCalls)
          .withToolResult(toolCallId: 'call_1', content: '{"temperature": 20}')
          .complete();

      final messages = provider.completionCalls.single.messages;
      expect(messages.map((message) => message.role), [
        MessageRole.user,
        MessageRole.assistant,
        MessageRole.tool,
      ]);
      expect(messages[1].toolCalls, same(toolCalls));
      expect(messages[2].toolCallId, 'call_1');
      expect(messages[2].content, '{"temperature": 20}');
    });

    test('can branch and reuse a builder without leaking messages', () async {
      final base = provider
          .chat(options: const ChatCompletionRequest(model: 'test-model'))
          .withSystemMessage('Shared system message');

      await base.withMessages(['First branch']).complete();
      await base.withMessages(['Second branch']).complete();

      expect(provider.completionCalls, hasLength(2));
      expect(
        provider.completionCalls[0].messages.map((message) => message.content),
        ['Shared system message', 'First branch'],
      );
      expect(
        provider.completionCalls[1].messages.map((message) => message.content),
        ['Shared system message', 'Second branch'],
      );
      expect(
        provider.completionCalls[0].messages,
        isNot(same(provider.completionCalls[1].messages)),
      );
    });

    test('delegates streaming with the built request', () async {
      const options = ChatCompletionRequest(model: 'test-model');

      final responses = await provider
          .chat(options: options)
          .withMessages(['Stream this'])
          .stream()
          .toList();

      expect(responses, provider.streamResponses);
      expect(provider.streamCalls, hasLength(1));
      expect(provider.streamCalls.single.options, same(options));
      expect(
        provider.streamCalls.single.messages.single.content,
        'Stream this',
      );
      expect(
        provider.streamCalls.single.messages.single.role,
        MessageRole.user,
      );
    });
  });
}

final class _FakeAIProvider implements AIProvider {
  _FakeAIProvider({
    required this.completionResponse,
    required this.streamResponses,
  });

  final ChatCompletionResponse completionResponse;
  final List<ChatCompletionStreamResponse> streamResponses;
  final List<_ProviderCall> completionCalls = [];
  final List<_ProviderCall> streamCalls = [];

  @override
  String get providerName => 'fake';

  @override
  Future<ChatCompletionResponse> chatCompletion({
    required List<ChatMessage> messages,
    required ChatCompletionRequest options,
  }) async {
    completionCalls.add(_ProviderCall(messages, options));
    return completionResponse;
  }

  @override
  Stream<ChatCompletionStreamResponse> streamChatCompletion({
    required List<ChatMessage> messages,
    required ChatCompletionRequest options,
  }) {
    streamCalls.add(_ProviderCall(messages, options));
    return Stream.fromIterable(streamResponses);
  }
}

final class _ProviderCall {
  const _ProviderCall(this.messages, this.options);

  final List<ChatMessage> messages;
  final ChatCompletionRequest options;
}
