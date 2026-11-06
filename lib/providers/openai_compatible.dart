import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/models/tool.dart';

Map<String, dynamic> toResponseFormat(ResponseFormat format) {
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

List<Map<String, dynamic>> toTools(List<Tool> tools) {
  return tools.map((t) => {
    'type': t.type,
    'function': {
      'name': t.name,
      if (t.description != null) 'description': t.description,
      if (t.parameters != null)
        'parameters': {
          'type': 'object',
          'properties': t.parameters,
          if (t.required != null && t.required!.isNotEmpty) 'required': t.required,
        },
    },
    if (t.strict != null) 'strict': t.strict,
  }).toList();
}

dynamic toToolChoice(ToolChoice choice) {
  return switch (choice) {
    ToolChoiceAuto() => 'auto',
    ToolChoiceNone() => 'none',
    ToolChoiceRequired() => 'required',
    ToolChoiceFunction(:final name) => {
      'type': 'function',
      'function': {'name': name},
    },
  };
}

Map<String, dynamic> toMessage(ChatMessage message) {
  return {
    'role': message.role.name,
    'content': message.content,
    if (message.name != null) 'name': message.name,
    if (message.toolCalls != null && message.toolCalls!.isNotEmpty)
      'tool_calls': message.toolCalls!.map((tc) => {
        'id': tc.id,
        'type': tc.type,
        'function': {
          'name': tc.function.name,
          'arguments': tc.function.arguments,
        },
      }).toList(),
    if (message.toolCallId != null) 'tool_call_id': message.toolCallId,
  };
}
