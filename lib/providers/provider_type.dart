enum ProviderType {
  openai('openai'),
  google('google'),
  anthropic('anthropic'),
  ollama('ollama'),
  mistral('mistral'),
  deepseek('deepseek');

  const ProviderType(this.id);

  final String id;

  static ProviderType fromId(String id) {
    return ProviderType.values.firstWhere(
          (p) => p.id == id.toLowerCase(),
      orElse: () => throw ArgumentError('Unknown provider id: "$id"'),
    );
  }

  @override
  String toString() => id;
}
