import 'dart:convert';
import 'dart:ffi';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
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
    final t0 = DateTime.now();
    debugPrint('[LocalLlmService] ${t0.toIso8601String()} 开始加载模型: ${_config.modelPath} (threads=${_config.threads}, ctx=${_config.contextSize})');
    _handle = _bindings.init(
      _config.modelPath!,
      _config.mmprojPath,
      _config.threads,
      _config.contextSize,
    );
    final t1 = DateTime.now();
    debugPrint('[LocalLlmService] ${t1.toIso8601String()} 模型加载完成，耗时 ${t1.difference(t0).inMilliseconds}ms');
    if (_handle == nullptr) {
      debugPrint('[LocalLlmService] 模型加载失败: ${_config.modelPath}');
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

    print('[LocalLlmService] ${DateTime.now().toIso8601String()} chat() start (hasImage=$hasImage, promptLen=${prompt.length})');

    if (hasImage) {
      // 多模态路径：base64 → RGB pixels → mllm_multimodal_complete
      final imageMsg = messages.firstWhere((m) => m.imageBase64 != null);
      return _multimodalComplete(prompt, imageMsg.imageBase64!, maxTokens, temperature);
    }

    // 纯文本路径
    final t0 = DateTime.now();
    print('[LocalLlmService] ${t0.toIso8601String()} 调用 _bindings.complete() ...');
    final result = _bindings.complete(_handle!, prompt, maxTokens, temperature);
    final t1 = DateTime.now();
    print('[LocalLlmService] ${t1.toIso8601String()} _bindings.complete() 返回，耗时 ${t1.difference(t0).inMilliseconds}ms');
    if (result == null) {
      throw StateError('推理失败 (complete 返回 null)');
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
    print('[LocalLlmService] ${DateTime.now().toIso8601String()} 图片解码完成: ${imageBytes.length} 字节');

    final imageDataPtr = malloc<Uint8>(imageBytes.length);
    imageDataPtr.asTypedList(imageBytes.length).setAll(0, imageBytes);

    try {
      final t0 = DateTime.now();
      print('[LocalLlmService] ${t0.toIso8601String()} 调用 _bindings.multimodalComplete() ... (maxTokens=$maxTokens)');
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
      final t1 = DateTime.now();
      print('[LocalLlmService] ${t1.toIso8601String()} multimodalComplete 返回，耗时 ${t1.difference(t0).inMilliseconds}ms');
      if (result == null) {
        throw StateError('多模态推理失败 (multimodalComplete 返回 null)');
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
      debugPrint('[LocalLlmService] ${DateTime.now().toIso8601String()} dispose() - 关闭模型句柄');
      _bindings.close(_handle!);
      _handle = null;
      debugPrint('[LocalLlmService] ${DateTime.now().toIso8601String()} dispose() 完成');
    }
  }
}

/// 在主线程中执行一次测试推理（加载模型 + 短推理 + 释放）
///
/// 返回推理结果字符串，失败返回 null。
/// ⚠️ 此方法包含同步 FFI 调用，会阻塞 UI 线程。
/// 调用方应先显示 loading dialog，再调用此方法。
String? runTestInference({
  required String modelPath,
  String? mmprojPath,
  required int threads,
  required int contextSize,
  required String prompt,
  required int maxTokens,
  required double temperature,
}) {
  debugPrint('[TestInference] 开始加载模型: $modelPath (threads=$threads, ctx=$contextSize)');
  final t0 = DateTime.now();
  final bindings = NativeLlmBindings();
  final handle = bindings.init(modelPath, mmprojPath, threads, contextSize);
  final t1 = DateTime.now();
  debugPrint('[TestInference] 模型加载 ${handle == nullptr ? "失败" : "成功"}，耗时 ${t1.difference(t0).inMilliseconds}ms');

  if (handle == nullptr) return null;

  try {
    debugPrint('[TestInference] 开始推理 (maxTokens=$maxTokens, temperature=$temperature)');
    final t2 = DateTime.now();
    final result = bindings.complete(handle, prompt, maxTokens, temperature);
    final t3 = DateTime.now();
    debugPrint('[TestInference] 推理完成，耗时 ${t3.difference(t2).inMilliseconds}ms, 结果: "$result"');
    return result;
  } finally {
    bindings.close(handle);
    debugPrint('[TestInference] 模型已关闭');
  }
}
