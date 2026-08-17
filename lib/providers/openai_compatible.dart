import 'package:ai_capo/models/response_format.dart';

/// Translates a [ResponseFormat] into the OpenAI-compatible `response_format`
/// payload used by OpenAI, DeepSeek and Mistral.
Map<String, dynamic> openAICompatibleResponseFormat(ResponseFormat format) {
  return switch (format.type) {
    ResponseFormatType.jsonObject => {'type': 'json_object'},
    ResponseFormatType.jsonSchema => {
        'type': 'json_schema',
        'json_schema': {
          if (format.name != null) 'name': format.name,
          if (format.strict != null) 'strict': format.strict,
          'schema': format.schema,
        },
      },
  };
}
