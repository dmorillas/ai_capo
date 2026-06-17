import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/providers/ai_provider.dart';
import 'package:ai_capo/providers/deepseek_provider.dart';
import 'package:ai_capo/providers/provider_type.dart';
import 'package:ai_capo/providers/openai_provider.dart';
import 'package:ai_capo/providers/anthropic_provider.dart';
import 'package:ai_capo/providers/google_provider.dart';
import 'package:ai_capo/providers/ollama_provider.dart';
import 'package:ai_capo/providers/mistral_provider.dart';

class AIClient {
  final Map<ProviderType, AIProvider> _providers = {};

  AIClient();

  AIProvider getProvider(ProviderType type, AIConfig config) {
    if (!_providers.containsKey(type)) {
      _providers[type] = switch (type) {
        ProviderType.openai => OpenAIProvider(config: config),
        ProviderType.anthropic => AnthropicProvider(config: config),
        ProviderType.google => GoogleProvider(config: config),
        ProviderType.ollama => OllamaProvider(config: config),
        ProviderType.mistral => MistralProvider(config: config),
        ProviderType.deepseek => DeepSeekProvider(config: config)
      };
    }
    return _providers[type]!;
  }

  List<ProviderType> get availableProviders {
    return _providers.keys.toList();
  }

  bool isProviderAvailable(ProviderType providerType) {
    return _providers.containsKey(providerType);
  }
}
