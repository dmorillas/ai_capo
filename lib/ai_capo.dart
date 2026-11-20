export 'exceptions/exceptions.dart';
export 'models/config.dart';
export 'models/message.dart';
export 'models/request.dart';
export 'models/response.dart';
export 'models/response_format.dart';
export 'models/stream_response.dart';
export 'providers/ai_provider.dart';
export 'providers/ai_provider_fluent.dart';
export 'providers/provider_type.dart';

/// A unified Flutter/Dart API for multiple Generative AI providers.
///
/// AI Capo (AI Client API Provider Orchestrator) gives a single, provider
/// agnostic interface for chat completions and streaming chat completions
/// across OpenAI, Anthropic Claude, Google Gemini, Ollama, Mistral and
/// DeepSeek.
///
/// Start by creating an [AIClient], request a provider with
/// [AIClient.getProvider], then generate responses with
/// [AIProvider.chatCompletion] or [AIProvider.streamChatCompletion]:
///
/// ```dart
/// final client = AIClient();
/// final config = AIConfig(apiKey: 'your-api-key');
/// final provider = client.getProvider(ProviderType.openai, config);
/// final response = await provider.chatCompletion(
///   messages: [ChatMessage.user('Hello!')],
///   options: ChatCompletionRequest(model: 'gpt-5-mini-2025-08-07'),
/// );
/// print(response.choices.first.content);
/// ```
library;

import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/providers/ai_provider.dart';
import 'package:ai_capo/providers/deepseek_provider.dart';
import 'package:ai_capo/providers/provider_type.dart';
import 'package:ai_capo/providers/openai_provider.dart';
import 'package:ai_capo/providers/anthropic_provider.dart';
import 'package:ai_capo/providers/google_provider.dart';
import 'package:ai_capo/providers/ollama_provider.dart';
import 'package:ai_capo/providers/mistral_provider.dart';

/// Orchestrates the AI providers exposed by this package.
///
/// The client instantiates providers lazily: the first call to [getProvider]
/// for a given [ProviderType] creates and caches the provider, and subsequent
/// calls return the cached instance.
class AIClient {
  final Map<ProviderType, AIProvider> _providers = {};

  /// Creates an empty client.
  ///
  /// No provider is created until [getProvider] is called.
  AIClient();

  /// Returns the provider for [type], creating and caching it on first use.
  ///
  /// [config] is only used when the provider is created; later calls with a
  /// different configuration return the already cached instance.
  AIProvider getProvider(ProviderType type, AIConfig config) {
    if (!_providers.containsKey(type)) {
      _providers[type] = switch (type) {
        ProviderType.openai => OpenAIProvider(config: config),
        ProviderType.anthropic => AnthropicProvider(config: config),
        ProviderType.google => GoogleProvider(config: config),
        ProviderType.ollama => OllamaProvider(config: config),
        ProviderType.mistral => MistralProvider(config: config),
        ProviderType.deepseek => DeepSeekProvider(config: config),
      };
    }
    return _providers[type]!;
  }

  /// The provider types that have already been instantiated by this client.
  List<ProviderType> get availableProviders {
    return _providers.keys.toList();
  }

  /// Whether a provider of [providerType] has already been created and cached.
  bool isProviderAvailable(ProviderType providerType) {
    return _providers.containsKey(providerType);
  }
}
