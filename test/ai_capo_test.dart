import 'package:ai_capo/exceptions/exceptions.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/models/response.dart';
import 'package:ai_capo/models/stream_response.dart';
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/providers/provider_type.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProviderType', () {
    test('values contains all expected providers', () {
      expect(ProviderType.values, hasLength(6));
      expect(ProviderType.openai.id, equals('openai'));
      expect(ProviderType.google.id, equals('google'));
      expect(ProviderType.anthropic.id, equals('anthropic'));
      expect(ProviderType.ollama.id, equals('ollama'));
      expect(ProviderType.mistral.id, equals('mistral'));
      expect(ProviderType.deepseek.id, equals('deepseek'));
    });

    test('fromId returns correct enum', () {
      expect(ProviderType.fromId('openai'), equals(ProviderType.openai));
      expect(ProviderType.fromId('anthropic'), equals(ProviderType.anthropic));
      expect(ProviderType.fromId('google'), equals(ProviderType.google));
      expect(ProviderType.fromId('ollama'), equals(ProviderType.ollama));
      expect(ProviderType.fromId('mistral'), equals(ProviderType.mistral));
      expect(ProviderType.fromId('deepseek'), equals(ProviderType.deepseek));
    });

    test('fromId is case insensitive', () {
      expect(ProviderType.fromId('OpenAI'), equals(ProviderType.openai));
      expect(ProviderType.fromId('ANTHROPIC'), equals(ProviderType.anthropic));
    });

    test('fromId throws for unknown provider', () {
      expect(
        () => ProviderType.fromId('unknown'),
        throwsArgumentError,
      );
    });

    test('toString returns id', () {
      expect(ProviderType.openai.toString(), equals('openai'));
      expect(ProviderType.anthropic.toString(), equals('anthropic'));
    });
  });

  group('ChatMessage', () {
    test('creates user message', () {
      final message = ChatMessage.user('Hello, world!');

      expect(message.role, equals(MessageRole.user));
      expect(message.content, equals('Hello, world!'));
    });

    test('creates system message', () {
      final message = ChatMessage.system('You are a helpful assistant.');

      expect(message.role, equals(MessageRole.system));
    });

    test('creates assistant message', () {
      final message = ChatMessage.assistant('Here is the answer.');

      expect(message.role, equals(MessageRole.assistant));
      expect(message.content, equals('Here is the answer.'));
    });

    test('toJson returns correct map', () {
      final message = ChatMessage.user('Test message');

      final json = message.toJson();
      expect(json['role'], equals('user'));
      expect(json['content'], equals('Test message'));
    });

    test('toJson includes name when set', () {
      final message = ChatMessage(
        role: MessageRole.user,
        content: 'Test message',
        name: 'test_user',
      );

      final json = message.toJson();
      expect(json['name'], equals('test_user'));
    });

    test('toJson omits name when null', () {
      final message = ChatMessage.user('Test message');

      final json = message.toJson();
      expect(json.containsKey('name'), isFalse);
    });

    test('supports equality of messages', () {
      final a = ChatMessage.user('Hello');
      final b = ChatMessage.user('Hello');

      expect(a.role, equals(b.role));
      expect(a.content, equals(b.content));
    });
  });

  group('MessageRole', () {
    test('fromString returns correct enum', () {
      expect(MessageRole.fromString('user'), equals(MessageRole.user));
      expect(MessageRole.fromString('system'), equals(MessageRole.system));
      expect(MessageRole.fromString('assistant'), equals(MessageRole.assistant));
    });

    test('fromString defaults to user for unknown', () {
      expect(MessageRole.fromString('unknown'), equals(MessageRole.user));
    });
  });

  group('ChatCompletionRequest', () {
    test('creates with defaults', () {
      const options = ChatCompletionRequest(model: 'gpt-4');

      expect(options.temperature, isNull);
      expect(options.maxTokens, isNull);
      expect(options.model, 'gpt-4');
      expect(options.topP, isNull);
    });

    test('creates with custom values', () {
      const options = ChatCompletionRequest(
        model: 'gpt-4',
        temperature: 0.9,
        maxTokens: 1000,
        topP: 0.95,
      );

      expect(options.temperature, equals(0.9));
      expect(options.maxTokens, equals(1000));
      expect(options.topP, equals(0.95));
    });

    test('supports all optional fields', () {
      final options = ChatCompletionRequest(
        model: 'gpt-4',
        temperature: 0.7,
        maxTokens: 500,
        topP: 0.9,
        topK: 40,
        stop: ['\n'],
        frequencyPenalty: 0.5,
        presencePenalty: 0.5,
        seed: 42,
        responseFormat: ResponseFormat(
          type: ResponseFormatType.jsonSchema,
          name: 'response',
          strict: true,
          schema: {'type': 'object'},
        ),
      );

      expect(options.model, equals('gpt-4'));
      expect(options.temperature, equals(0.7));
      expect(options.maxTokens, equals(500));
      expect(options.topP, equals(0.9));
      expect(options.topK, equals(40));
      expect(options.stop, equals(['\n']));
      expect(options.frequencyPenalty, equals(0.5));
      expect(options.presencePenalty, equals(0.5));
      expect(options.seed, equals(42));
      expect(options.responseFormat?.type, equals(ResponseFormatType.jsonSchema));
      expect(options.responseFormat?.name, equals('response'));
      expect(options.responseFormat?.strict, isTrue);
    });
  });

  group('ResponseFormat', () {
    test('jsonObject does not require a schema', () {
      final format = ResponseFormat(type: ResponseFormatType.jsonObject);

      expect(format.type, equals(ResponseFormatType.jsonObject));
      expect(format.schema, isNull);
    });

    test('jsonSchema stores the schema', () {
      final format = ResponseFormat(
        type: ResponseFormatType.jsonSchema,
        schema: {'type': 'object'},
      );

      expect(format.schema, equals({'type': 'object'}));
    });

    test('jsonSchema throws when schema is null', () {
      expect(
        () => ResponseFormat(type: ResponseFormatType.jsonSchema),
        throwsArgumentError,
      );
    });
  });

  group('ChatCompletionResponse', () {
    test('creates with choices', () {
      final now = DateTime.now();
      final response = ChatCompletionResponse(
        choices: [
          const ChatCompletionChoice(
            index: 0,
            content: 'Hello!',
            finishReason: 'stop',
          ),
        ],
        timestamp: now,
      );

      expect(response.choices, hasLength(1));
      expect(response.choices.first.content, equals('Hello!'));
      expect(response.choices.first.finishReason, equals('stop'));
      expect(response.model, isNull);
      expect(response.provider, isNull);
    });

    test('creates with all fields', () {
      final now = DateTime.now();
      final response = ChatCompletionResponse(
        model: 'gpt-4',
        provider: 'openai',
        choices: [
          const ChatCompletionChoice(
            index: 0,
            content: 'Hello!',
            finishReason: 'stop',
          ),
          const ChatCompletionChoice(
            index: 1,
            content: 'Hi!',
            finishReason: 'stop',
          ),
        ],
        usage: {'total_tokens': 50},
        rawResponse: {'id': '123'},
        timestamp: now,
      );

      expect(response.model, equals('gpt-4'));
      expect(response.provider, equals('openai'));
      expect(response.choices, hasLength(2));
      expect(response.usage, containsPair('total_tokens', 50));
      expect(response.rawResponse, containsPair('id', '123'));
      expect(response.timestamp, equals(now));
    });

    test('creates choice with finishReason', () {
      const choice = ChatCompletionChoice(
        index: 0,
        content: 'Response',
        finishReason: 'length',
      );

      expect(choice.index, equals(0));
      expect(choice.content, equals('Response'));
      expect(choice.finishReason, equals('length'));
    });
  });

  group('ChatCompletionStreamResponse', () {
    test('creates with content', () {
      const response = ChatCompletionStreamResponse(
        content: 'Hello',
        isComplete: false,
      );

      expect(response.content, equals('Hello'));
      expect(response.isComplete, isFalse);
    });

    test('creates with complete flag', () {
      const response = ChatCompletionStreamResponse(
        content: '',
        isComplete: true,
      );

      expect(response.isComplete, isTrue);
    });

    test('creates with optional fields', () {
      const response = ChatCompletionStreamResponse(
        content: 'Hello',
        isComplete: true,
        model: 'gpt-4',
        provider: 'openai',
      );

      expect(response.model, equals('gpt-4'));
      expect(response.provider, equals('openai'));
    });

    group('fromJson', () {
      test('parses OpenAI-style streaming response', () {
        final json = {
          'choices': [
            {
              'delta': {'content': 'Hello'},
              'finish_reason': null,
            },
          ],
          'model': 'gpt-4o-mini',
        };

        final response = ChatCompletionStreamResponse.fromJson(
          json,
          provider: 'openai',
        );

        expect(response.content, equals('Hello'));
        expect(response.isComplete, isFalse);
        expect(response.model, equals('gpt-4o-mini'));
        expect(response.provider, equals('openai'));
      });

      test('parses OpenAI-style complete response', () {
        final json = {
          'choices': [
            {
              'delta': {'content': ''},
              'finish_reason': 'stop',
            },
          ],
        };

        final response = ChatCompletionStreamResponse.fromJson(json);

        expect(response.content, equals(''));
        expect(response.isComplete, isTrue);
      });

      test('parses Gemini-style streaming response', () {
        final json = {
          'candidates': [
            {
              'content': {
                'parts': [{'text': 'Hello from Gemini'}],
              },
              'finishReason': null,
            },
          ],
        };

        final response = ChatCompletionStreamResponse.fromJson(
          json,
          provider: 'google',
        );

        expect(response.content, equals('Hello from Gemini'));
        expect(response.isComplete, isFalse);
      });

      test('parses Gemini-style complete response', () {
        final json = {
          'candidates': [
            {
              'content': {
                'parts': [{'text': 'Done'}],
              },
              'finishReason': 'STOP',
            },
          ],
        };

        final response = ChatCompletionStreamResponse.fromJson(json);

        expect(response.isComplete, isTrue);
      });

      test('parses Ollama-style streaming response', () {
        final json = {
          'delta': {'content': 'Hello from Ollama'},
          'done': false,
        };

        final response = ChatCompletionStreamResponse.fromJson(
          json,
          provider: 'ollama',
        );

        expect(response.content, equals('Hello from Ollama'));
        expect(response.isComplete, isFalse);
      });

      test('parses Ollama-style complete response', () {
        final json = {
          'delta': {'content': 'Done'},
          'done': true,
        };

        final response = ChatCompletionStreamResponse.fromJson(json);

        expect(response.isComplete, isTrue);
      });

      test('throws on error response', () {
        final json = {
          'error': {'message': 'API error occurred'},
        };

        expect(
          () => ChatCompletionStreamResponse.fromJson(json),
          throwsA(isA<AIException>()),
        );
      });
    });

    group('parseSseLine', () {
      test('parses valid SSE data line', () {
        final line = 'data: {"choices":[{"delta":{"content":"Hello"},"finish_reason":null}]}';
        final response = ChatCompletionStreamResponse.parseSseLine(
          line,
          provider: 'openai',
        );

        expect(response.content, equals('Hello'));
        expect(response.isComplete, isFalse);
      });

      test('handles [DONE] signal', () {
        final line = 'data: [DONE]';
        final response = ChatCompletionStreamResponse.parseSseLine(
          line,
          provider: 'openai',
        );

        expect(response.isComplete, isTrue);
        expect(response.content, equals(''));
      });

      test('returns empty for non-data line', () {
        final line = 'event: ping';
        final response = ChatCompletionStreamResponse.parseSseLine(line);

        expect(response.content, equals(''));
        expect(response.isComplete, isFalse);
      });

      test('handles malformed JSON gracefully', () {
        final line = 'data: {invalid json}';
        final response = ChatCompletionStreamResponse.parseSseLine(line);

        expect(response.content, equals(''));
        expect(response.isComplete, isFalse);
      });

      test('handles empty SSE data', () {
        final line = 'data:';
        final response = ChatCompletionStreamResponse.parseSseLine(line);

        expect(response.content, equals(''));
        expect(response.isComplete, isFalse);
      });
    });
  });

  group('AIConfig', () {
    test('creates with defaults', () {
      const config = AIConfig();

      expect(config.apiKey, isNull);
      expect(config.defaultMaxTokens, equals(2048));
      expect(config.timeout, equals(Duration(seconds: 120)));
    });

    test('creates with custom values', () {
      const config = AIConfig(
        apiKey: 'test-key',
        ollamaBaseUrl: 'http://localhost:11434',
        defaultMaxTokens: 1000,
        timeout: Duration(seconds: 60),
      );

      expect(config.apiKey, equals('test-key'));
      expect(config.ollamaBaseUrl, equals('http://localhost:11434'));
      expect(config.defaultMaxTokens, equals(1000));
      expect(config.timeout, equals(Duration(seconds: 60)));
    });
  });

  group('AIException', () {
    test('creates with message', () {
      const exception = AIException('Test error');
      expect(exception.message, equals('Test error'));
    });

    test('creates with provider', () {
      const exception = AIException('Test error', provider: 'openai');
      expect(exception.provider, equals('openai'));
    });

    test('creates with status code', () {
      const exception = AIException('Test error', statusCode: 429);
      expect(exception.statusCode, equals(429));
    });

    test('creates with details', () {
      const exception = AIException(
        'Test error',
        details: {'key': 'value'},
      );
      expect(exception.details, containsPair('key', 'value'));
    });

    test('toString includes provider and status code', () {
      const exception = AIException(
        'Rate limit',
        provider: 'openai',
        statusCode: 429,
      );
      expect(exception.toString(), contains('AIException'));
      expect(exception.toString(), contains('openai'));
      expect(exception.toString(), contains('429'));
    });

    test('subclasses are instances of AIException', () {
      const configEx = AIConfigurationException('Config error');
      const authEx = AIAuthenticationException('Auth error');
      const rateEx = AIRateLimitException('Rate limit');
      const netEx = AINetworkException('Network error');
      const modelEx = AIModelNotSupportedException('Unsupported model');

      expect(configEx, isA<AIException>());
      expect(authEx, isA<AIException>());
      expect(rateEx, isA<AIException>());
      expect(netEx, isA<AIException>());
      expect(modelEx, isA<AIException>());
    });
  });
}
