import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

class AiClient {
  final String ollamaBaseUrl;
  final Map<String, String> apiKeys;
  TokenUsage? lastUsage;

  AiClient({String? ollamaBaseUrl, this.apiKeys = const {}})
      : ollamaBaseUrl = ollamaBaseUrl ?? _defaultOllamaUrl();

  static String _defaultOllamaUrl() {
    if (kIsWeb) {
      final pageHost = Uri.base.host;
      return 'http://$pageHost:11434';
    }
    return 'http://127.0.0.1:11434';
  }

  Future<AiResponse> chat(String model, List<ChatMessage> messages) async {
    if (model.startsWith('openai:')) {
      return _chatOpenAI(model.replaceFirst('openai:', ''), messages);
    } else if (model.startsWith('gemini:')) {
      return _chatGemini(model.replaceFirst('gemini:', ''), messages);
    } else if (model.startsWith('anthropic:')) {
      return _chatAnthropic(model.replaceFirst('anthropic:', ''), messages);
    } else if (model.startsWith('openrouter:')) {
      return _chatOpenRouter(model.replaceFirst('openrouter:', ''), messages);
    } else if (model.startsWith('perplexity:')) {
      return _chatPerplexity(model.replaceFirst('perplexity:', ''), messages);
    } else {
      return _chatOllama(model, messages);
    }
  }

  Future<AiResponse> _chatOllama(String model, List<ChatMessage> messages) async {
    final url = Uri.parse('$ollamaBaseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toOllamaJson()).toList(),
      'stream': false,
    });

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final msg = ChatMessage.fromJson(data['message']);
      final usage = TokenUsage(
        promptTokens: data['prompt_eval_count'] ?? 0,
        completionTokens: data['eval_count'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: msg, usage: usage);
    } else {
      throw Exception('Ollama error: ${response.body}');
    }
  }

  Future<AiResponse> _chatOpenAI(String model, List<ChatMessage> messages) async {
    final key = apiKeys['openai'];
    if (key == null || key.isEmpty) throw Exception('OpenAI API Key not set.');

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final u = data['usage'];
      final usage = TokenUsage(
        promptTokens: u['prompt_tokens'] ?? 0,
        completionTokens: u['completion_tokens'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: ChatMessage(role: 'assistant', content: content), usage: usage);
    } else {
      throw Exception('OpenAI error: ${response.body}');
    }
  }

  Future<AiResponse> _chatGemini(String model, List<ChatMessage> messages) async {
    final key = apiKeys['gemini'];
    if (key == null || key.isEmpty) throw Exception('Gemini API Key not set.');

    final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$key');
    
    // Extract system instruction if present
    Map<String, dynamic>? systemInstruction;
    final systemIdx = messages.indexWhere((m) => m.role == 'system');
    if (systemIdx != -1) {
      systemInstruction = {
        'parts': [{'text': messages[systemIdx].content}]
      };
    }

    // Gemini roles: user, model
    final filteredMessages = messages.where((m) => m.role != 'system').toList();
    final contents = filteredMessages.map((m) => {
      'role': m.role == 'assistant' ? 'model' : 'user',
      'parts': [{'text': m.content}]
    }).toList();

    final bodyMap = <String, dynamic>{
      'contents': contents,
    };
    if (systemInstruction != null) {
      bodyMap['system_instruction'] = systemInstruction;
    }

    final body = jsonEncode(bodyMap);

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['candidates'][0]['content']['parts'][0]['text'];
      final u = data['usageMetadata'];
      final usage = TokenUsage(
        promptTokens: u['promptTokenCount'] ?? 0,
        completionTokens: u['candidatesTokenCount'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: ChatMessage(role: 'assistant', content: content), usage: usage);
    } else {
      throw Exception('Gemini error: ${response.body}');
    }
  }

  Future<AiResponse> _chatAnthropic(String model, List<ChatMessage> messages) async {
    final key = apiKeys['anthropic'];
    if (key == null || key.isEmpty) throw Exception('Anthropic API Key not set.');

    final url = Uri.parse('https://api.anthropic.com/v1/messages');
    
    // Extract system message
    String? systemMessage;
    final systemIdx = messages.indexWhere((m) => m.role == 'system');
    if (systemIdx != -1) {
      systemMessage = messages[systemIdx].content;
    }

    final bodyMap = {
      'model': model,
      'max_tokens': 4096,
      'messages': messages.where((m) => m.role != 'system').map((m) => {'role': m.role, 'content': m.content}).toList(),
    };
    if (systemMessage != null) {
      bodyMap['system'] = systemMessage;
    }

    final body = jsonEncode(bodyMap);

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': key,
        'anthropic-version': '2023-06-01',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['content'][0]['text'];
      final u = data['usage'];
      final usage = TokenUsage(
        promptTokens: u['input_tokens'] ?? 0,
        completionTokens: u['output_tokens'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: ChatMessage(role: 'assistant', content: content), usage: usage);
    } else {
      throw Exception('Anthropic error: ${response.body}');
    }
  }

  Future<AiResponse> _chatOpenRouter(String model, List<ChatMessage> messages) async {
    final key = apiKeys['openrouter'];
    if (key == null || key.isEmpty) throw Exception('OpenRouter API Key not set.');

    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
        'HTTP-Referer': 'https://govgen.research',
        'X-Title': 'GovGen Research Suite',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final u = data['usage'];
      final usage = TokenUsage(
        promptTokens: u['prompt_tokens'] ?? 0,
        completionTokens: u['completion_tokens'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: ChatMessage(role: 'assistant', content: content), usage: usage);
    } else {
      throw Exception('OpenRouter error: ${response.body}');
    }
  }

  Future<AiResponse> _chatPerplexity(String model, List<ChatMessage> messages) async {
    final key = apiKeys['perplexity'];
    if (key == null || key.isEmpty) throw Exception('Perplexity API Key not set.');

    final url = Uri.parse('https://api.perplexity.ai/chat/completions');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => {'role': m.role, 'content': m.content}).toList(),
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $key',
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      final u = data['usage'];
      final usage = TokenUsage(
        promptTokens: u['prompt_tokens'] ?? 0,
        completionTokens: u['completion_tokens'] ?? 0,
      );
      lastUsage = usage;
      return AiResponse(message: ChatMessage(role: 'assistant', content: content), usage: usage);
    } else {
      throw Exception('Perplexity error: ${response.body}');
    }
  }

  // Stream implementation (simplified for brevity, can be expanded)
  Stream<String> chatStream(String model, List<ChatMessage> messages, {http.Client? client}) async* {
    lastUsage = null; // Reset usage before operation
    if (model.contains(':')) {
      final res = await chat(model, messages);
      yield res.message.content;
    } else {
      yield* _chatStreamOllama(model, messages, client: client);
    }
  }

  Stream<String> _chatStreamOllama(String model, List<ChatMessage> messages, {http.Client? client}) async* {
     final url = Uri.parse('$ollamaBaseUrl/api/chat');
    final body = jsonEncode({
      'model': model,
      'messages': messages.map((m) => m.toOllamaJson()).toList(),
      'stream': true,
    });

    final httpClient = client ?? http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers.addAll({'Content-Type': 'application/json'});
      request.body = body;
      final response = await httpClient.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.trim().isEmpty) continue;
            try {
              final data = jsonDecode(line);
              if (data.containsKey('message')) yield data['message']['content'] as String;
            } catch (_) {}
          }
        }
      }
    } finally {
      if (client == null) httpClient.close();
    }
  }

  Future<List<String>> listModels() async {
    final url = Uri.parse('$ollamaBaseUrl/api/tags');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final localModels = (data['models'] as List).map((m) => m['name'] as String).toList();
        
        // Add common cloud models if keys are present
        final all = [...localModels];
        if (apiKeys.containsKey('openai')) all.addAll(['openai:gpt-4o', 'openai:gpt-4-turbo', 'openai:gpt-3.5-turbo']);
        if (apiKeys.containsKey('gemini')) all.addAll(['gemini:gemini-1.5-pro', 'gemini:gemini-1.5-flash']);
        if (apiKeys.containsKey('anthropic')) all.add('anthropic:claude-3-5-sonnet-20240620');
        if (apiKeys.containsKey('openrouter')) {
          all.addAll([
            'openrouter:anthropic/claude-3.5-sonnet',
            'openrouter:openai/gpt-4o',
            'openrouter:meta-llama/llama-3.1-405b-instruct',
            'openrouter:qwen/qwen-2.5-72b-instruct',
            'openrouter:deepseek/deepseek-chat',
            'openrouter:meta-llama/llama-3-70b-instruct'
          ]);
        }
        if (apiKeys.containsKey('perplexity')) all.addAll(['perplexity:llama-3.1-sonar-large-128k-online', 'perplexity:llama-3.1-sonar-small-128k-online']);
        
        return all;
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
