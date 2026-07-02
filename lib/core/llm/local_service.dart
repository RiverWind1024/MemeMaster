import 'llm_service.dart';
import 'local_config.dart';
import 'models.dart';

/// 本地 LLM 推理服务（基于 llamafu / llama.cpp）
///
/// 支持纯文本和 vision 多模态模型。
/// 模型通过 ModelManager 下载后加载。
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;

  LocalLlmService({required LocalLlmConfig config}) : _config = config;

  @override
  bool get isAvailable => _config.modelPath != null;

  @override
  String get modelName {
    final path = _config.modelPath;
    if (path == null) return 'none';
    return path.split('/').last.replaceAll('.gguf', '');
  }

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

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  }) async {
    // TODO: 集成 llamafu 后实现真实推理
    // 1. 按需加载 _engine
    // 2. 根据是否有图片决定使用 multimodalComplete 或 complete
    // 3. 解析流式/非流式输出
    throw UnimplementedError('本地推理将在 llamafu 集成后实现');
  }

  @override
  void dispose() {
    // TODO: 释放 llamafu engine
  }
}
