# AI Capo: AI Client API Provider Orchestrator

<p align="center">
  <img src="https://raw.githubusercontent.com/dmorillas/ai_capo/refs/heads/main/ai_capo.png" alt="AI Capo" width="400"/>
</p>

A unified Flutter/Dart API for multiple Generative AI providers. AI Capo simplifies LLM integration by providing a clean, pluggable architecture for OpenAI, Anthropic Claude, Google Gemini, Ollama, Mistral, and DeepSeek.

## Features

- **Multi-Provider Support**: Switch between OpenAI, Anthropic, Google, Ollama, Mistral, and DeepSeek.
- **Unified Interface**: All providers implement the same `AIProvider` abstraction.
- **Streaming**: Full streaming support for real-time responses.
- **Lazy Initialization**: Providers are created on first request and cached.
- **Structured Output**: JSON Schema enforcement via `ResponseFormat` across all providers.
- **Tool Calling**: Define functions the model can call, control tool selection, and consume streamed tool-call deltas.

## Getting Started

Add `ai_capo` to your `pubspec.yaml`:

```yaml
dependencies:
  ai_capo: ^1.1.0
```

Run `flutter pub get`.

## Usage

### 1. Create an AIClient

```dart
import 'package:ai_capo/ai_capo.dart';

final client = AIClient();
```

### 2. Configure Your API Key

Pass a config when requesting a provider:

```dart
final config = AIConfig(apiKey: 'your-api-key');
```

### 3. Generate a Response

```dart
final provider = client.getProvider(ProviderType.openai, config);
final response = await provider.chatCompletion(
  messages: [ChatMessage.user('What is Flutter?')],
  options: const ChatCompletionRequest(
    model: 'gpt-5-mini-2025-08-07',
    temperature: 0.7,
    maxTokens: 500,
  ),
);

print(response.choices.first.content);
```

### 4. Switch Providers

```dart
final anthropic = client.getProvider(ProviderType.anthropic, config);
final response = await anthropic.chatCompletion(
  messages: [ChatMessage.user('Hello, Claude!')],
);
```

### 5. Stream a Response

```dart
final provider = client.getProvider(ProviderType.openai, config);

await for (final chunk in provider.streamChatCompletion(
  messages: [ChatMessage.user('Write a short poem.')],
  options: const ChatCompletionRequest(model: 'gpt-5-mini-2025-08-07', temperature: 0.8),
)) {
  print(chunk.content);
}
```

### 6. Use a System Prompt

```dart
final provider = client.getProvider(ProviderType.openai, config);
final response = await provider.chatCompletion(
  messages: [
    ChatMessage.system('You are a helpful Python tutor.'),
    ChatMessage.user('How do list comprehensions work?'),
  ],
);
```

---

## Tool Calling

Tool calling (also known as function calling) lets you describe functions the model may invoke. Pass the available tools via `tools` and, optionally, control selection with `toolChoice`.

`Tool.parameters` is a map of **property name → JSON Schema** (not a full schema), and `Tool.required` lists the property names that must be provided.

```dart
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/tool.dart';
```

### 1. Define tools and request a completion

```dart
final provider = client.getProvider(ProviderType.openai, config);

final response = await provider.chatCompletion(
  messages: [ChatMessage.user('What is the weather in Paris?')],
  options: ChatCompletionRequest(
    model: 'gpt-5-mini-2025-08-07',
    tools: const [
      Tool(
        name: 'get_weather',
        description: 'Get the current weather for a city.',
        parameters: {
          'location': {
            'type': 'string',
            'description': 'The city to get the weather for.',
          },
        },
        required: ['location'],
      ),
    ],
    toolChoice: ToolChoice.auto(),
  ),
);

final toolCalls = response.choices.first.toolCalls;
if (toolCalls != null) {
  for (final call in toolCalls) {
    print('${call.id}: ${call.function.name}(${call.function.arguments})');
  }
}
```

`FunctionCallResult.arguments` is a JSON-encoded string (for example `{"location":"Paris"}`).

### 2. Send the tool result back

Append the assistant's tool calls and a `ChatMessage.tool(...)` containing the result, then request a completion again:

```dart
final toolCall = response.choices.first.toolCalls!.first;

final finalResponse = await provider.chatCompletion(
  messages: [
    ChatMessage.user('What is the weather in Paris?'),
    ChatMessage.assistant('', toolCalls: response.choices.first.toolCalls),
    ChatMessage.tool(
      toolCallId: toolCall.id,
      content: '{"temperature": 20}',
    ),
  ],
  options: const ChatCompletionRequest(model: 'gpt-5-mini-2025-08-07'),
);

print(finalResponse.choices.first.content);
```

> For Google Gemini, the tool result `content` must be valid JSON, since it is decoded before being sent as a function response.

### 3. Stream tool calls

Streaming responses expose incremental `ToolCallDelta` objects on `chunk.toolCalls`. Accumulate them by `index` until the stream ends, then build the complete `ToolCall` list:

```dart
final indices = <int>{};
final ids = <int, String>{};
final names = <int, String>{};
final args = <int, StringBuffer>{};

await for (final chunk in provider.streamChatCompletion(
  messages: [ChatMessage.user('What is the weather in Paris?')],
  options: ChatCompletionRequest(
    model: 'gpt-5-mini-2025-08-07',
    tools: const [
      Tool(
        name: 'get_weather',
        description: 'Get the current weather for a city.',
        parameters: {
          'location': {'type': 'string'},
        },
        required: ['location'],
      ),
    ],
    toolChoice: ToolChoice.auto(),
  ),
)) {
  for (final delta in chunk.toolCalls ?? const <ToolCallDelta>[]) {
    indices.add(delta.index);
    if (delta.id != null) ids[delta.index] = delta.id!;
    if (delta.function?.name != null) {
      names[delta.index] = delta.function!.name!;
    }
    final partial = delta.function?.arguments;
    if (partial != null) {
      (args[delta.index] ??= StringBuffer()).write(partial);
    }
  }
}

final toolCalls = indices.map((index) => ToolCall(
  id: ids[index] ?? '',
  function: FunctionCallResult(
    name: names[index],
    arguments: args[index]?.toString(),
  ),
)).toList();
```

Then send the results back exactly as in the non-streaming flow.

### Tool choice

| Value | Meaning |
| --- | --- |
| `ToolChoice.auto()` | The model decides whether to call a tool. |
| `ToolChoice.none()` | The model must not call any tool. |
| `ToolChoice.required()` | The model must call at least one tool. |
| `ToolChoice.function('get_weather')` | The model must call the named tool. |

### Provider support

Tools are supported by all providers. `toolChoice` is honored by OpenAI, DeepSeek, Mistral and Anthropic; Ollama and Google Gemini accept `tools` but ignore `toolChoice`.

| Provider | Tools | `toolChoice` | Streaming tool deltas |
| --- | --- | --- | --- |
| OpenAI | ✅ | ✅ | ✅ |
| DeepSeek | ✅ | ✅ | ✅ |
| Mistral | ✅ | ✅ | ✅ |
| Anthropic | ✅ | ✅ | ✅ |
| Ollama | ✅ | — | ✅ |
| Google Gemini | ✅ | — | ✅ |

---

## Structured Output

Structured output lets you enforce a JSON schema on the model's response. Use the `ResponseFormat` model via `responseFormat`. Each provider translates it into its own wire format (`response_format` for OpenAI/DeepSeek/Mistral, `output_config` for Anthropic, `responseJsonSchema` for Google, `format` for Ollama).

### JSON object mode

Pass `ResponseFormatType.jsonObject` to request plain JSON output:

```dart
final response = await provider.chatCompletion(
  messages: [ChatMessage.user('List 3 colors.')],
  options: ChatCompletionRequest(
    model: 'gpt-5-mini-2025-08-07',
    responseFormat: const ResponseFormat(type: ResponseFormatType.jsonObject),
  ),
);

// response.choices.first.content is a JSON string
```

Supported by: OpenAI, DeepSeek, Mistral, Ollama, Google.
Anthropic does not support schema-less JSON output — use `jsonSchema` instead.

### JSON Schema mode

Pass `ResponseFormatType.jsonSchema` with a `schema`:

```dart
final response = await provider.chatCompletion(
  messages: [
    ChatMessage.system('Extract info from the text.'),
    ChatMessage.user('The iPhone 16 costs $999 and was released in September 2024.'),
  ],
  options: ChatCompletionRequest(
    model: 'gpt-5-mini-2025-08-07',
    responseFormat: ResponseFormat(
      type: ResponseFormatType.jsonSchema,
      name: 'product_info',
      strict: true,
      schema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string'},
          'price': {'type': 'number'},
          'release_date': {'type': 'string'},
        },
        'required': ['name', 'price', 'release_date'],
        'additionalProperties': false,
      },
    ),
  ),
);

print(response.choices.first.content);
```

Supported by: OpenAI, DeepSeek, Mistral, Ollama, Google, Anthropic.

`name` and `strict` are optional and only used by providers that support them. `schema` is required when `type` is `jsonSchema`; passing a null schema throws an `ArgumentError`.

---

## **Contribution**

Feel free to open an issue or submit a pull request on GitHub.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
