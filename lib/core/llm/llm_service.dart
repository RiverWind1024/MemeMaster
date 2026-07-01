import 'models.dart';
export 'models.dart';

/// LLM 服务抽象接口
///
/// 支持多供应商（OpenAI、Ollama 等），调用方无需关心具体实现。
abstract class LlmService {
  /// 发送聊天补全请求，返回生成的文本
  Future<String> complete(
    String prompt, {
    LlmOptions? options,
  });

  /// 发送多轮聊天请求（带 system prompt 和历史消息）
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  });

  /// 服务是否可用（已配置且服务器可达）
  bool get isAvailable;

  /// 当前使用的模型名称
  String get modelName;

  void dispose();
}
