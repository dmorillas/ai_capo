/// Models for tool (function) calling.
library;

/// A tool (function) definition the model may call.
///
/// [parameters] is a map of property name to JSON Schema (not a full schema)
/// and [required] lists the property names the model must always provide.
///
/// ```dart
/// const Tool(
///   name: 'get_weather',
///   description: 'Get the current weather for a city.',
///   parameters: {
///     'location': {'type': 'string'},
///   },
///   required: ['location'],
/// );
/// ```
class Tool {
  /// The type of the tool, currently always `function`.
  final String type;

  /// The name of the function to call.
  final String name;

  /// A description of what the function does, used by the model.
  final String? description;

  /// The function parameters: property name to JSON Schema.
  final Map<String, dynamic>? parameters;

  /// The names of the parameters the model must always provide.
  final List<String>? required;

  /// Whether the provider should strictly enforce the schema
  /// (OpenAI compatible providers).
  final bool? strict;

  /// Creates a tool definition.
  const Tool({
    this.type = 'function',
    required this.name,
    this.description,
    this.parameters,
    this.required,
    this.strict,
  });
}

/// Controls whether and which tool the model must call.
///
/// Use the factory constructors to pick a behaviour:
/// [ToolChoice.auto], [ToolChoice.none], [ToolChoice.required] or
/// [ToolChoice.function] to force a specific function.
sealed class ToolChoice {
  /// Creates a tool choice.
  const ToolChoice();

  /// The model decides whether to call a tool.
  const factory ToolChoice.auto() = ToolChoiceAuto;

  /// The model must not call any tool.
  const factory ToolChoice.none() = ToolChoiceNone;

  /// The model must call at least one tool.
  const factory ToolChoice.required() = ToolChoiceRequired;

  /// The model must call the function named [name].
  factory ToolChoice.function(String name) = ToolChoiceFunction;
}

/// The model decides whether to call a tool.
class ToolChoiceAuto extends ToolChoice {
  /// Creates the automatic tool choice.
  const ToolChoiceAuto();
}

/// The model must not call any tool.
class ToolChoiceNone extends ToolChoice {
  /// Creates the "no tool" choice.
  const ToolChoiceNone();
}

/// The model must call at least one tool.
class ToolChoiceRequired extends ToolChoice {
  /// Creates the "a tool must be called" choice.
  const ToolChoiceRequired();
}

/// The model must call the function with the given [name].
class ToolChoiceFunction extends ToolChoice {
  /// The name of the function that must be called.
  final String name;

  /// Creates a tool choice forcing the function named [name].
  const ToolChoiceFunction(this.name);
}

/// A tool call requested by the model in a non-streamed response.
///
/// [FunctionCallResult.arguments] contains the arguments as a JSON-encoded
/// string (for example `{"location":"Paris"}`).
class ToolCall {
  /// The provider-assigned identifier of this call.
  ///
  /// Use it as the `toolCallId` of the matching [ChatMessage.tool] when
  /// sending the result back.
  final String id;

  /// The type of the call, currently always `function`.
  final String type;

  /// The function the model requested.
  final FunctionCallResult function;

  /// An optional provider-specific signature attached to the call
  /// (Google Gemini thinking models).
  final String? thoughtSignature;

  /// Creates a tool call.
  const ToolCall({
    required this.id,
    this.type = 'function',
    required this.function,
    this.thoughtSignature,
  });
}

/// The function requested by a [ToolCall], and its arguments.
class FunctionCallResult {
  /// The name of the function to call.
  final String? name;

  /// The arguments of the call, as a JSON-encoded string.
  final String? arguments;

  /// Creates a function call result.
  const FunctionCallResult({this.name, this.arguments});
}

/// An incremental tool call produced while streaming.
///
/// Deltas belonging to the same call share the same [index]; accumulate them
/// until the stream ends to rebuild the complete [ToolCall].
class ToolCallDelta {
  /// The position of this call among the calls of the response.
  final int index;

  /// The provider-assigned identifier of the call, when available.
  final String? id;

  /// The type of the call, currently always `function`.
  final String? type;

  /// The function name and the incremental arguments of the call.
  final FunctionCallResult? function;

  /// An optional provider-specific signature attached to the call
  /// (Google Gemini thinking models).
  final String? thoughtSignature;

  /// Creates a tool call delta.
  const ToolCallDelta({
    required this.index,
    this.id,
    this.type,
    this.function,
    this.thoughtSignature,
  });
}
