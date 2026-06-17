class AIConfig {
  final String? apiKey;
  final String? ollamaBaseUrl;
  final String? providerVersion;
  final String? googleProjectId;
  final String? googleRegion;
  final int defaultMaxTokens;
  final Duration timeout;

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

