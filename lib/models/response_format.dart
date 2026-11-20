/// Structured output (response format) model.
library;

/// The kind of structured output requested from a model.
enum ResponseFormatType {
  /// Requests a plain JSON object, without a specific schema.
  jsonObject,

  /// Requests JSON output that conforms to a JSON schema.
  jsonSchema,
}

/// Requests structured JSON output from a model.
///
/// Use [ResponseFormatType.jsonObject] for plain JSON output, or
/// [ResponseFormatType.jsonSchema] (with [schema]) to enforce a specific
/// shape:
///
/// ```dart
/// ResponseFormat(
///   type: ResponseFormatType.jsonSchema,
///   name: 'product_info',
///   schema: {
///     'type': 'object',
///     'properties': {
///       'name': {'type': 'string'},
///     },
///   },
/// )
/// ```
///
/// Anthropic does not support schema-less JSON output; use
/// [ResponseFormatType.jsonSchema] with that provider.
class ResponseFormat {
  /// The kind of structured output requested.
  final ResponseFormatType type;

  /// The JSON schema the response must conform to.
  ///
  /// Required when [type] is [ResponseFormatType.jsonSchema], otherwise an
  /// [ArgumentError] is thrown.
  final Map<String, dynamic>? schema;

  /// An optional name for the schema, used by providers that support it.
  final String? name;

  /// Whether the provider should strictly enforce the schema.
  final bool? strict;

  /// Creates a response format.
  ResponseFormat({required this.type, this.schema, this.name, this.strict}) {
    if (type == ResponseFormatType.jsonSchema && schema == null) {
      throw ArgumentError(
        'schema is required when type is ResponseFormatType.jsonSchema',
        'schema',
      );
    }
  }
}
