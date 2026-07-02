import 'llm_service.dart';
import 'openai_service.dart';

/// Ollama 本地 LLM 服务
///
/// Ollama 从 0.1.37+ 起提供了 `/v1/chat/completions` 兼容端点，
/// 因此复用 [OpenAiLlmService] 实现。默认连接到 localhost:11434。
///
  /// 如果需要在 Android 模拟器中使用，baseUrl 需设为 `http://10.0.2.2:11434/v1`。
class OllamaLlmService implements LlmService {
  final OpenAiLlmService _inner;

  OllamaLlmService({
    String baseUrl = 'http://localhost:11434/v1',
    String model = 'llama3.2',
  }) : _inner = OpenAiLlmService(
          baseUrl: baseUrl,
          apiKey: '',
          model: model,
        );

  @override
  bool get isAvailable => true;

  @override
  String get modelName => _inner.modelName;

  @override
  Future<String> complete(String prompt, {LlmOptions? options}) {
    return _inner.complete(prompt, options: options);
  }

  @override
  Future<String> chat(List<LlmMessage> messages, {LlmOptions? options}) {
    return _inner.chat(messages, options: options);
  }

  @override
  void dispose() => _inner.dispose();
}
