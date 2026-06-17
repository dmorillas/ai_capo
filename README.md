# AI Capo: AI Client API Provider Orchestrator

A unified Flutter/Dart API for multiple Generative AI providers. AI Capo simplifies LLM integration by providing a clean, pluggable architecture for OpenAI, Anthropic Claude, Google Gemini, Ollama, Mistral, and DeepSeek.

## Features

- **Multi-Provider Support**: Switch between OpenAI, Anthropic, Google, Ollama, Mistral, and DeepSeek.
- **Unified Interface**: All providers implement the same `AIProvider` abstraction.
- **Streaming**: Full streaming support for real-time responses.
- **Lazy Initialization**: Providers are created on first request and cached.

## Getting Started

Add `ai_capo` to your `pubspec.yaml`:

```yaml
dependencies:
  ai_capo: ^1.0.0
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
  options: const ChatCompletionRequest(temperature: 0.8),
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

## **Contribution**

Feel free to open an issue or submit a pull request on GitHub.

## License

This project is licensed under the MIT License. See `LICENSE` for details.
