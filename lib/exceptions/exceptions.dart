/// Exceptions thrown by AI Capo providers.
library;

/// The base exception for all errors reported by AI Capo.
///
/// Subclasses narrow the most common failure causes; [provider] and
/// [statusCode] identify where the failure originated when known.
class AIException implements Exception {
  /// A human-readable description of the failure.
  final String message;

  /// The name of the provider that reported the failure.
  final String? provider;

  /// The HTTP status code of the failed request, when applicable.
  final int? statusCode;

  /// Additional provider-specific details about the failure.
  final Map<String, dynamic>? details;

  /// Creates an AI exception.
  const AIException(
    this.message, {
    this.provider,
    this.statusCode,
    this.details,
  });

  /// Returns a description of the failure, including the provider and the
  /// status code when available.
  @override
  String toString() {
    final buffer = StringBuffer('AIException');
    if (provider != null) buffer.write(' [$provider]');
    buffer.write(': $message');
    if (statusCode != null) buffer.write(' (status: $statusCode)');
    return buffer.toString();
  }
}

/// Thrown when a provider is misconfigured, for example a missing API key.
class AIConfigurationException extends AIException {
  /// Creates a configuration exception.
  const AIConfigurationException(super.message, {super.provider});
}

/// Thrown when a provider rejects the credentials.
class AIAuthenticationException extends AIException {
  /// Creates an authentication exception.
  const AIAuthenticationException(
    super.message, {
    super.provider,
    super.statusCode,
  });
}

/// Thrown when a provider reports that the rate limit was exceeded.
class AIRateLimitException extends AIException {
  /// Creates a rate limit exception.
  const AIRateLimitException(super.message, {super.provider, super.statusCode});
}

/// Thrown when a request fails at the network level or times out.
class AINetworkException extends AIException {
  /// Creates a network exception.
  const AINetworkException(super.message, {super.provider});
}

/// Thrown when a provider does not support the requested feature or model.
class AIModelNotSupportedException extends AIException {
  /// Creates a "not supported" exception.
  const AIModelNotSupportedException(super.message, {super.provider});
}
