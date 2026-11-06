class Tool {
  final String type;
  final String name;
  final String? description;
  final Map<String, dynamic>? parameters;
  final List<String>? required;
  final bool? strict;

  const Tool({
    this.type = 'function',
    required this.name,
    this.description,
    this.parameters,
    this.required,
    this.strict,
  });
}

sealed class ToolChoice {
  const ToolChoice();
  const factory ToolChoice.auto() = ToolChoiceAuto;
  const factory ToolChoice.none() = ToolChoiceNone;
  const factory ToolChoice.required() = ToolChoiceRequired;
  factory ToolChoice.function(String name) = ToolChoiceFunction;
}

class ToolChoiceAuto extends ToolChoice {
  const ToolChoiceAuto();
}

class ToolChoiceNone extends ToolChoice {
  const ToolChoiceNone();
}

class ToolChoiceRequired extends ToolChoice {
  const ToolChoiceRequired();
}

class ToolChoiceFunction extends ToolChoice {
  final String name;
  const ToolChoiceFunction(this.name);
}

class ToolCall {
  final String id;
  final String type;
  final FunctionCallResult function;
  final String? thoughtSignature;

  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
    this.thoughtSignature,
  });
}

class FunctionCallResult {
  final String? name;
  final String? arguments;

  const FunctionCallResult({
    this.name,
    this.arguments,
  });
}

class ToolCallDelta {
  final int index;
  final String? id;
  final String? type;
  final FunctionCallResult? function;
  final String? thoughtSignature;

  const ToolCallDelta({
    required this.index,
    this.id,
    this.type,
    this.function,
    this.thoughtSignature,
  });
}
