import 'package:ai_capo/models/response_format.dart';

class ChatCompletionRequest {
  final String model;
  final double? temperature;
  final int? maxTokens;
  final double? topP;
  final int? topK;
  final List<String>? stop;
  final double? frequencyPenalty;
  final double? presencePenalty;
  final int? seed;
  final ResponseFormat? responseFormat;
  final Map<String, dynamic>? customParameters;

  const ChatCompletionRequest({
    required this.model,
    this.temperature,
    this.maxTokens,
    this.topP,
    this.topK,
    this.stop,
    this.frequencyPenalty,
    this.presencePenalty,
    this.seed,
    this.responseFormat,
    this.customParameters,
  });
}
