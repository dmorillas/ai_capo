/// Configuration shared by all providers.
library;

/// Holds the settings used to create and configure AI providers.
///
/// The same configuration object can be shared between providers. Only the
/// fields relevant to each provider are used (for example, [apiKey] is used
/// by the hosted providers while [ollamaBaseUrl] is used by Ollama).
///
/// ```dart
/// const config = AIConfig(
///   apiKey: 'your-api-key',
///   timeout: Duration(seconds: 30),
/// );
/// ```
class AIConfig {
  /// The API key used to authenticate with the provider.
  ///
  /// Required by OpenAI, Anthropic, Google, Mistral and DeepSeek. Ollama
  /// runs locally and does not require a key.
  final String? apiKey;

  /// The base URL of the Ollama server.
  ///
  /// Defaults to `http://localhost:11434` when not provided.
  final String? ollamaBaseUrl;

  /// The API version to send in the provider-specific version header.
  ///
  /// Used by Anthropic (for example `2023-06-01`) as the `anthropic-version`
  /// header; it is required by the Anthropic provider.
  final String? providerVersion;

  /// The Google Cloud project identifier associated with the Google provider.
  final String? googleProjectId;

  /// The Google Cloud region associated with the Google provider.
  final String? googleRegion;

  /// The maximum number of tokens a request may generate when
  /// [ChatCompletionRequest.maxTokens] is not set.
  ///
  /// Defaults to `2048`.
  final int defaultMaxTokens;

  /// How long a provider waits for a response before timing out.
  ///
  /// Timeouts are reported as [AINetworkException]. Defaults to 120 seconds.
  final Duration timeout;

  /// Creates a provider configuration.
  const AIConfig({
    this.apiKey,
    this.ollamaBaseUrl,
    this.providerVersion,
    this.googleProjectId,
    this.googleRegion,
    this.defaultMaxTokens = 2048,
    this.timeout = const Duration(seconds: 120),
  });
}
