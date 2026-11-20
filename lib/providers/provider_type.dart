/// The list of providers supported by AI Capo.
library;

/// The AI providers supported by [AIClient].
enum ProviderType {
  /// OpenAI (for example `gpt-5-mini-2025-08-07`).
  openai('openai'),

  /// Google Gemini (via Firebase AI Logic, for example
  /// `gemini-3.1-flash-lite`).
  google('google'),

  /// Anthropic Claude (for example `claude-haiku-4-5-20251001`).
  anthropic('anthropic'),

  /// A local Ollama server (for example `llama3.2`).
  ollama('ollama'),

  /// Mistral AI (for example `mistral-small-latest`).
  mistral('mistral'),

  /// DeepSeek (for example `deepseek-chat`).
  deepseek('deepseek');

  /// Creates a provider type with its [id].
  const ProviderType(this.id);

  /// The stable identifier of this provider, used by [fromId].
  final String id;

  /// Returns the provider type matching [id].
  ///
  /// The comparison is case-insensitive. Throws an [ArgumentError] when no
  /// provider matches.
  static ProviderType fromId(String id) {
    return ProviderType.values.firstWhere(
      (p) => p.id == id.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown provider id: "$id"'),
    );
  }

  /// Returns the [id] of this provider.
  @override
  String toString() => id;
}
