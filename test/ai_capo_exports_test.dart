import 'package:ai_capo/ai_capo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('public barrel exports the provider-neutral API', () {
    // Importing only package:ai_capo/ai_capo.dart must be enough to build a
    // request that uses tool calling.
    const tool = Tool(name: 'get_weather');
    final request = ChatCompletionRequest(
      model: 'test-model',
      tools: [tool],
      toolChoice: ToolChoice.auto(),
      responseFormat: ResponseFormat(type: ResponseFormatType.jsonObject),
    );

    expect(request.tools!.single, same(tool));
    expect(request.toolChoice, isA<ToolChoiceAuto>());
    expect(request.responseFormat!.type, ResponseFormatType.jsonObject);
    expect(ChatMessage.user('hello').role, MessageRole.user);
    expect(AIClient(), isA<AIClient>());
  });
}
