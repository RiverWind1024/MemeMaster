import 'package:llamafu/llamafu.dart';

import 'llm_service.dart';
import 'local_config.dart';
import 'models.dart';

/// 本地 LLM 推理服务（基于 llamafu / llama.cpp）
///
/// 支持纯文本和 vision 多模态模型。
/// 模型通过 ModelManager 下载后加载。
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;
  Llamafu? _engine;

  LocalLlmService({required LocalLlmConfig config}) : _config = config;

  @override
  bool get isAvailable => _config.modelPath != null;

  @override
  String get modelName {
    final path = _config.modelPath;
    if (path == null) return 'none';
    return path.split('/').last.replaceAll('.gguf', '');
  }

  Future<void> _ensureLoaded() async {
    if (_engine != null) return;
    if (_config.modelPath == null) {
      throw StateError('模型未加载，请先下载模型');
    }
    _engine = await Llamafu.init(
      modelPath: _config.modelPath!,
      mmprojPath: _config.mmprojPath,
      threads: _config.threads,
      contextSize: _config.contextSize,
    );
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
    await _ensureLoaded();

    final engine = _engine!;
    final hasImage = messages.any((m) => m.imageBase64 != null);
    final prompt = messages.map((m) => '${m.role}: ${m.content}').join('\n');

    if (hasImage) {
      final imageMsg = messages.firstWhere((m) => m.imageBase64 != null);
      return engine.multimodalComplete(
        prompt: prompt,
        mediaInputs: [
          MediaInput(
            type: MediaType.image,
            data: imageMsg.imageBase64!,
          ),
        ],
        maxTokens: options?.maxTokens ?? 512,
        temperature: options?.temperature ?? 0.7,
      );
    }

    return engine.complete(
      prompt: prompt,
      maxTokens: options?.maxTokens ?? 512,
      temperature: options?.temperature ?? 0.7,
    );
  }

  @override
  void dispose() {
    _engine?.close();
    _engine = null;
  }
}
