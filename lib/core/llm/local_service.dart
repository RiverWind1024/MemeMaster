import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'llm_service.dart';
import 'local_config.dart';
import 'models.dart';
import 'native_bindings.dart';

/// 本地 LLM 推理服务（基于 llama.cpp 原生 C API）
///
/// 支持纯文本和 vision 多模态模型。
/// 模型通过 ModelManager 下载后加载。
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;
  final NativeLlmBindings _bindings = NativeLlmBindings();
  Pointer<Void>? _handle;

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
    if (_handle != null) return;
    if (_config.modelPath == null) {
      throw StateError('模型未加载，请先下载模型');
    }
    _handle = _bindings.init(
      _config.modelPath!,
      _config.mmprojPath,
      _config.threads,
      _config.contextSize,
    );
    if (_handle == nullptr) {
      throw StateError('模型加载失败: ${_config.modelPath}');
    }
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

    final prompt = messages.map((m) => '${m.role}: ${m.content}').join('\n');
    final maxTokens = options?.maxTokens ?? 512;
    final temperature = options?.temperature ?? 0.7;

    final hasImage = messages.any((m) => m.imageBase64 != null);

    if (hasImage) {
      // 多模态路径：base64 → RGB pixels → mllm_multimodal_complete
      final imageMsg = messages.firstWhere((m) => m.imageBase64 != null);
      return _multimodalComplete(prompt, imageMsg.imageBase64!, maxTokens, temperature);
    }

    // 纯文本路径
    final result = _bindings.complete(_handle!, prompt, maxTokens, temperature);
    if (result == null) {
      throw StateError('推理失败');
    }
    return result;
  }

  Future<String> _multimodalComplete(
    String prompt,
    String base64Image,
    int maxTokens,
    double temperature,
  ) async {
    // base64 解码为原始 bytes，假设是 JPEG/PNG
    // 目前 C 侧期望 RGB 像素数据，这里先用 base64 原始数据占位
    // TODO: 在 Dart 侧将图片解码为 RGB 像素后传入
    final imageBytes = _decodeBase64(base64Image);

    final imageDataPtr = malloc<Uint8>(imageBytes.length);
    imageDataPtr.asTypedList(imageBytes.length).setAll(0, imageBytes);

    try {
      final result = _bindings.multimodalComplete(
        _handle!,
        prompt,
        imageDataPtr,
        imageBytes.length,
        0, // width: 0 让 C 侧判断
        0, // height: 0 让 C 侧判断
        maxTokens,
        temperature,
      );
      if (result == null) {
        throw StateError('多模态推理失败');
      }
      return result;
    } finally {
      malloc.free(imageDataPtr);
    }
  }

  Uint8List _decodeBase64(String base64Str) {
    return Uint8List.fromList(base64Decode(base64Str));
  }

  @override
  void dispose() {
    if (_handle != null) {
      _bindings.close(_handle!);
      _handle = null;
    }
  }
}
