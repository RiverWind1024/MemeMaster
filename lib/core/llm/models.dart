import 'package:collection/collection.dart';

/// LLM 请求参数
class LlmOptions {
  final String? model;
  final double temperature;
  final int maxTokens;

  const LlmOptions({
    this.model,
    this.temperature = 0.7,
    this.maxTokens = 512,
  });

  Map<String, Object?> toJson() => {
        if (model != null) 'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
      };
}

/// 聊天消息
class LlmMessage {
  final String role; // 'system' | 'user' | 'assistant'
  final String content;

  /// 可选的 base64 编码图片（多模态 vision 使用）
  final String? imageBase64;

  const LlmMessage({
    required this.role,
    required this.content,
    this.imageBase64,
  });

  Map<String, String> toJson() => {'role': role, 'content': content};
}

/// LLM 补全请求
class LlmCompletionRequest {
  final List<LlmMessage> messages;
  final LlmOptions options;

  const LlmCompletionRequest({
    required this.messages,
    this.options = const LlmOptions(),
  });

  Map<String, Object?> toJson() => {
        ...options.toJson(),
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}

/// LLM 补全响应（简化，仅提取文本内容）
class LlmCompletionResponse {
  final String content;
  final String? model;
  final int? promptTokens;
  final int? completionTokens;

  const LlmCompletionResponse({
    required this.content,
    this.model,
    this.promptTokens,
    this.completionTokens,
  });

  factory LlmCompletionResponse.fromOpenAiJson(Map<String, dynamic> json) {
    final choice = (json['choices'] as List?)?.firstOrNull;
    final message = choice?['message'] as Map<String, dynamic>?;
    final usage = json['usage'] as Map<String, dynamic>?;
    return LlmCompletionResponse(
      content: (message?['content'] as String?)?.trim() ?? '',
      model: json['model'] as String?,
      promptTokens: usage?['prompt_tokens'] as int?,
      completionTokens: usage?['completion_tokens'] as int?,
    );
  }
}
