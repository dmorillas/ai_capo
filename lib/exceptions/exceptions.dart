class AIException implements Exception {
  final String message;
  final String? provider;
  final int? statusCode;
  final Map<String, dynamic>? details;

  const AIException(
    this.message, {
    this.provider,
    this.statusCode,
    this.details,
  });

  @override
  String toString() {
    final buffer = StringBuffer('AIException');
    if (provider != null) buffer.write(' [$provider]');
    buffer.write(': $message');
    if (statusCode != null) buffer.write(' (status: $statusCode)');
    return buffer.toString();
  }
}

class AIConfigurationException extends AIException {
  const AIConfigurationException(super.message, {super.provider});
}

class AIAuthenticationException extends AIException {
  const AIAuthenticationException(
    super.message, {
    super.provider,
    super.statusCode,
  });
}

class AIRateLimitException extends AIException {
  const AIRateLimitException(super.message, {super.provider, super.statusCode});
}

class AINetworkException extends AIException {
  const AINetworkException(super.message, {super.provider});
}

class AIModelNotSupportedException extends AIException {
  const AIModelNotSupportedException(super.message, {super.provider});
}
