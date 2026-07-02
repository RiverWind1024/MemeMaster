import 'dart:convert';

import 'package:http/http.dart' as http;

import 'llm_service.dart';

/// OpenAI 兼容 API 的 LLM 服务实现
///
/// 直接兼容：OpenAI API、Groq、DeepSeek、SiliconFlow、Together AI 等
/// 间接兼容（通过适配）：Ollama（启用 `/?format=json` 后 API shape 一致）
class OpenAiLlmService implements LlmService {
  final String _baseUrl;
  final String _apiKey;
  final String _model;
  final http.Client _client;

  OpenAiLlmService({
    required String baseUrl,
    required this._apiKey,
    this._model = 'gpt-4o-mini',
    http.Client? client,
  })  : _baseUrl = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
        _client = client ?? http.Client();

  /// 拼接完整的 API endpoint URL
  ///
  /// baseUrl 应包含版本前缀，如:
  ///   - OpenAI:  https://api.openai.com/v1
  ///   - 讯飞 v2: https://maas-api.cn-huabei-1.xf-yun.com/v2
  ///   - Ollama:  http://localhost:11434/v1
  Uri get _endpoint => Uri.parse('${_baseUrl}chat/completions');

  @override
  bool get isAvailable => _apiKey.isNotEmpty;

  @override
  String get modelName => _model;

  @override
  Future<String> complete(
    String prompt, {
    LlmOptions? options,
  }) async {
    return chat(
      [LlmMessage(role: 'user', content: prompt)],
      options: options,
    );
  }

  /// 构建消息体，支持多模态 vision 消息
  List<Map<String, dynamic>> _buildMessages(List<LlmMessage> messages) {
    return messages.map((msg) {
      if (msg.imageBase64 != null) {
        return {
          'role': msg.role,
          'content': [
            {'type': 'text', 'text': msg.content},
            {
              'type': 'image_url',
              'image_url': {
                'url': 'data:image/jpeg;base64,${msg.imageBase64}',
              },
            },
          ],
        };
      }
      return msg.toJson();
    }).toList();
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  }) async {
    final request = LlmCompletionRequest(
      messages: messages,
      options: options ?? const LlmOptions(model: null),
    );

    // 如果 options 没有指定 model，使用构造函数传来的默认 model
    final body = {
      ...request.toJson(),
      if (options?.model == null) 'model': _model,
      'messages': _buildMessages(messages),
    };

    final response = await _client.post(
      _endpoint,
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey.isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw LlmException(
        'API returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final result = LlmCompletionResponse.fromOpenAiJson(data);
    return result.content;
  }

  @override
  void dispose() {
    _client.close();
  }
}

class LlmException implements Exception {
  final String message;
  const LlmException(this.message);

  @override
  String toString() => 'LlmException: $message';
}
