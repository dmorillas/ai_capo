enum ResponseFormatType {
  jsonObject,
  jsonSchema,
}

class ResponseFormat {
  final ResponseFormatType type;
  final Map<String, dynamic>? schema;
  final String? name;
  final bool? strict;

  ResponseFormat({
    required this.type,
    this.schema,
    this.name,
    this.strict,
  }) {
    if (type == ResponseFormatType.jsonSchema && schema == null) {
      throw ArgumentError(
        'schema is required when type is ResponseFormatType.jsonSchema',
        'schema',
      );
    }
  }
}
