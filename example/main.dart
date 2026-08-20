import 'dart:convert';
import 'package:ai_capo/models/config.dart';
import 'package:ai_capo/models/message.dart';
import 'package:ai_capo/models/request.dart';
import 'package:ai_capo/models/response_format.dart';
import 'package:ai_capo/providers/provider_type.dart';
import 'package:flutter/material.dart';
import 'package:ai_capo/ai_capo.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Capo Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AICapoDemo(),
    );
  }
}

class AICapoDemo extends StatefulWidget {
  const AICapoDemo({super.key});

  @override
  State<AICapoDemo> createState() => _AICapoDemoState();
}

class _AICapoDemoState extends State<AICapoDemo> {
  final AIClient _client = AIClient();
  final TextEditingController _promptController = TextEditingController();
  String _response = '';
  bool _isLoading = false;
  final String _selectedProvider = 'openai:gpt-5-mini-2025-08-07';
  String _provider = 'openai';
  String _model = 'gpt-5-mini-2025-08-07';

  AIConfig get _config => const AIConfig(apiKey: 'YOUR_API_KEY');

  Future<void> _generateResponse() async {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final provider = _client.getProvider(
        ProviderType.fromId(_provider),
        _config,
      );
      final response = await provider.chatCompletion(
        messages: [ChatMessage.user(_promptController.text)],
        options: ChatCompletionRequest(
          model: _model,
          temperature: 1,
        ),
      );

      setState(() {
        _response = response.choices.first.content ?? '';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _generateStreamResponse() async {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final provider = _client.getProvider(
        ProviderType.fromId(_provider),
        _config,
      );
      await for (final chunk in provider.streamChatCompletion(
        messages: [ChatMessage.user(_promptController.text)],
        options: ChatCompletionRequest(
          model: _model,
          temperature: 1,
        ),
      )) {
        setState(() {
          _response += chunk.content;
        });
      }
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _generateStructuredOutput() async {
    if (_promptController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _response = '';
    });

    try {
      final provider = _client.getProvider(
        ProviderType.fromId(_provider),
        _config,
      );
      final response = await provider.chatCompletion(
        messages: [
          ChatMessage.system('You are a helpful assistant. Always respond with valid JSON.'),
          ChatMessage.user(_promptController.text),
        ],
        options: ChatCompletionRequest(
          model: _model,
          temperature: 1,
          responseFormat: ResponseFormat(
            type: ResponseFormatType.jsonSchema,
            name: 'response',
            strict: true,
            schema: {
              'type': 'object',
              'properties': {
                'summary': {'type': 'string'},
                'sentiment': {'type': 'string', 'enum': ['positive', 'negative', 'neutral']},
                'keywords': {
                  'type': 'array',
                  'items': {'type': 'string'},
                },
              },
              'required': ['summary', 'sentiment', 'keywords'],
              'additionalProperties': false,
            },
          ),
        ),
      );

      final content = response.choices.first.content ?? '';
      final prettyJson = const JsonEncoder.withIndent('  ').convert(jsonDecode(content));

      setState(() {
        _response = prettyJson;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Capo Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedProvider,
              decoration: const InputDecoration(
                labelText: 'Provider',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'openai:gpt-5-mini-2025-08-07', child: Text('OpenAI')),
                DropdownMenuItem(value: 'anthropic:claude-haiku-4-5-20251001', child: Text('Anthropic')),
                DropdownMenuItem(value: 'google:gemini-3.1-flash-lite', child: Text('Google Gemini')),
                DropdownMenuItem(value: 'ollama:llama3.2', child: Text('Ollama')),
                DropdownMenuItem(value: 'mistral:mistral-small-latest', child: Text('Mistral')),
                DropdownMenuItem(value: 'deepseek:deepseek-chat', child: Text('DeepSeek')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _provider = value.split(':')[0].toLowerCase();
                    _model = value.split(':')[1].toLowerCase();
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Enter your prompt',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateResponse,
                  child: const Text('Generate'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateStreamResponse,
                  child: const Text('Stream'),
                ),
                ElevatedButton(
                  onPressed: _isLoading ? null : _generateStructuredOutput,
                  child: const Text('Structured'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: SelectableText(
                  _isLoading ? 'Loading...' : _response,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }
}
