import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ffi/ffi.dart';
import 'package:image/image.dart' as img;

import '../../services/log_service.dart';
import 'llm_service.dart';
import 'local_config.dart';
import 'models.dart';
import 'native_bindings.dart';

/// C++ 端 mllm_init 写入的日志文件路径（同时给 logcat 和这个文件）
/// 路径由调用方通过 path_provider 解析后传入，这里只作占位（实际路径在 init 那一刻决定）
String? _mllmLogFilePath;
void setMllmLogFilePath(String? path) {
  _mllmLogFilePath = path;
}
String? getMllmLogFilePath() => _mllmLogFilePath;

/// 可跨 isolate 传递的模型加载参数
class _InitIsolateArgs {
  final SendPort sendPort;
  final String modelPath;
  final String? mmprojPath;
  final int threads;
  final int contextSize;
  final int useGpu;
  final int nGpuLayers;
  final String? logFilePath;

  _InitIsolateArgs({
    required this.sendPort,
    required this.modelPath,
    this.mmprojPath,
    required this.threads,
    required this.contextSize,
    required this.useGpu,
    required this.nGpuLayers,
    this.logFilePath,
  });
}

/// 在后台 isolate 中执行模型加载（不阻塞主线程），通过 SendPort 返回 handle address
void _initIsolateEntry(_InitIsolateArgs args) {
  final bindings = NativeLlmBindings();
  final handle = bindings.init(
    args.modelPath,
    args.mmprojPath,
    args.threads,
    args.contextSize,
    useGpu: args.useGpu,
    nGpuLayers: args.nGpuLayers,
    logFilePath: args.logFilePath,
  );
  args.sendPort.send(handle.address);
}

/// 可跨 isolate 传递的文本测试推理参数
class _TextRunTestArgs {
  final SendPort sendPort;
  final String modelPath;
  final String? mmprojPath;
  final int threads;
  final int contextSize;
  final String prompt;
  final int maxTokens;
  final double temperature;

  _TextRunTestArgs({
    required this.sendPort,
    required this.modelPath,
    this.mmprojPath,
    required this.threads,
    required this.contextSize,
    required this.prompt,
    required this.maxTokens,
    required this.temperature,
  });
}

/// 在后台 isolate 中执行测试推理（加载模型→推理→释放，全部在 isolate 内完成）
///
/// 被 [Isolate.spawn] 调用，通过 [SendPort] 返回结果字符串或 null。
void _textRunTestInferenceIsolateEntry(_TextRunTestArgs args) {
  final bindings = NativeLlmBindings();
  final handle = bindings.init(
    args.modelPath,
    args.mmprojPath,
    args.threads,
    args.contextSize,
    useGpu: 0,
    nGpuLayers: 0,
    logFilePath: _mllmLogFilePath,
  );

  if (handle == nullptr) {
    args.sendPort.send(null);
    return;
  }

  try {
    final result = bindings.complete(
      handle,
      args.prompt,
      args.maxTokens,
      args.temperature,
    );
    args.sendPort.send(result);
  } catch (e) {
    args.sendPort.send(null);
  } finally {
    bindings.close(handle);
  }
}

/// 可跨 isolate 传递的多模态推理参数
class _MultimodalIsolateArgs {
  final SendPort sendPort;
  final int handleAddress;
  final String prompt;
  final Uint8List rgbBytes;
  final int imageWidth;
  final int imageHeight;
  final int maxTokens;
  final double temperature;

  _MultimodalIsolateArgs({
    required this.sendPort,
    required this.handleAddress,
    required this.prompt,
    required this.rgbBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.maxTokens,
    required this.temperature,
  });
}

/// 在后台 isolate 中执行多模态推理（同步 FFI 调用，避免阻塞主线程 ANR）
///
/// 被 [Isolate.spawn] 调用，通过 [SendPort] 返回结果。
/// 在 isolate 内部重新创建 [NativeLlmBindings] 和 malloc 内存。
void _multimodalCompleteIsolateEntry(_MultimodalIsolateArgs args) {
  final handle = Pointer<Void>.fromAddress(args.handleAddress);
  final bindings = NativeLlmBindings();
  final imageDataPtr = malloc<Uint8>(args.rgbBytes.length);
  imageDataPtr.asTypedList(args.rgbBytes.length).setAll(0, args.rgbBytes);
  try {
    final result = bindings.multimodalComplete(
      handle,
      args.prompt,
      imageDataPtr,
      args.rgbBytes.length,
      args.imageWidth,
      args.imageHeight,
      args.maxTokens,
      args.temperature,
    );
    args.sendPort.send(result);
  } catch (e) {
    args.sendPort.send(null);
  } finally {
    malloc.free(imageDataPtr);
  }
}

/// 本地 LLM 推理服务（基于 llama.cpp 原生 C API）
///
/// 支持纯文本和 vision 多模态模型。
/// 模型通过 ModelManager 下载后加载。
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;
  final NativeLlmBindings _bindings = NativeLlmBindings();
  final LogService _log = LogService();
  Pointer<Void>? _handle;

  /// 标记服务已释放，拒绝新操作
  bool _disposed = false;

  /// Future-chain 操作序列化：所有 handle 操作排队执行，防止并发 FFI
  Completer<void>? _opCompleter;

  /// 通过 Future-chain 串行化 FFI 操作，避免并发崩溃
  /// 每个操作会等待前一个完成后再执行，保证 handle 的独占访问
  /// [force] = true 时跳过 _disposed 检查，供 dispose 内部使用
  Future<T> _runSerialized<T>(Future<T> Function() fn, {bool force = false}) async {
    if (!force && _disposed) throw StateError('服务已释放');

    final prev = _opCompleter?.future ?? Future<void>.value();
    final completer = Completer<void>();
    _opCompleter = completer;

    await prev;
    if (!force && _disposed) throw StateError('服务已释放');

    try {
      return await fn();
    } finally {
      completer.complete();
    }
  }

  LocalLlmService({required LocalLlmConfig config}) : _config = config;

  @override
  bool get isAvailable => _config.modelPath != null;

  /// 检查模型是否已加载（用于延迟加载）
  bool get isLoaded => _handle != null;

  /// 等比缩放图片到最大边长 [maxDim]，返回 (宽, 高, 缩放后的 Image)
  static (int, int, img.Image) _resizeKeepingAspectRatio(img.Image image, int maxDim) {
    int w = image.width;
    int h = image.height;
    if (w > h) {
      h = (h * maxDim / w).round();
      w = maxDim;
    } else {
      w = (w * maxDim / h).round();
      h = maxDim;
    }
    final resized = img.copyResize(image, width: w, height: h);
    return (w, h, resized);
  }

  /// 公开的模型加载方法，供外部按需加载模型
  ///
  /// 通过序列化锁防止与 chat/dispose 并发，异常透传。
  Future<void> ensureLoaded() {
    return _runSerialized(() => _ensureLoaded());
  }

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
    final effectiveThreads = _config.effectiveThreads;
    debugPrint('[LocalLlmService] ${t0.toIso8601String()} 开始加载模型: ${_config.modelPath} (threads=$effectiveThreads, ctx=${_config.contextSize}, rawConfig.threads=${_config.threads})');

    // 通过 Isolate 加载模型，避免阻塞主线程；带 60s 超时
    final receivePort = ReceivePort();
    final args = _InitIsolateArgs(
      sendPort: receivePort.sendPort,
      modelPath: _config.modelPath!,
      mmprojPath: _config.mmprojPath,
      threads: effectiveThreads,
      contextSize: _config.contextSize,
      useGpu: _config.useGpu ? 1 : 0,
      nGpuLayers: _config.useGpu ? -1 : 0,
      logFilePath: _mllmLogFilePath,
    );

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_initIsolateEntry, args);

      final address = await receivePort.first.timeout(const Duration(seconds: 60));
      if (address == 0) {
        throw StateError('模型加载失败: ${_config.modelPath}');
      }
      _handle = Pointer<Void>.fromAddress(address as int);
      final t1 = DateTime.now();
      debugPrint('[LocalLlmService] ${t1.toIso8601String()} 模型加载完成，耗时 ${t1.difference(t0).inMilliseconds}ms');
    } on TimeoutException {
      isolate?.kill(priority: Isolate.immediate);
      debugPrint('[LocalLlmService] 模型加载超时 (60s): ${_config.modelPath}');
      throw StateError('模型加载超时 (60s): ${_config.modelPath}');
    } finally {
      receivePort.close();
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
    return _runSerialized(() async {
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
    });
  }

  Future<String> _multimodalComplete(
    String prompt,
    String base64Image,
    int maxTokens,
    double temperature,
  ) async {
    // base64 解码为原始 bytes，然后转换为 RGB 像素
    final imageBytes = _decodeBase64(base64Image);
    
    // 使用 image 包解码图片并转换为 RGB
    final decodedImage = img.decodeImage(imageBytes);
    if (decodedImage == null) {
      throw StateError('无法解码图片');
    }
    
    // 检查图片尺寸，防止内存溢出
    final pixelCount = decodedImage.width * decodedImage.height;
    if (pixelCount > 1024 * 1024) {  // 超过1百万像素
      _log.warning('LocalLlmService', '图片过大 (${decodedImage.width}x${decodedImage.height})，可能导致内存不足');
    }
    
    // 进一步压缩图片尺寸，减少 mtmd vision encoder 计算量
    // 本地 LLM 推理是 CPU 瓶颈，降低分辨率可大幅加速
    const int maxLocalDim = 384;
    final decodeW = decodedImage.width;
    final decodeH = decodedImage.height;
    final (targetW, targetH, resizedImage) = 
        (decodeW > maxLocalDim || decodeH > maxLocalDim)
            ? _resizeKeepingAspectRatio(decodedImage, maxLocalDim)
            : (decodeW, decodeH, decodedImage);
    _log.info('LocalLlmService', '图片 ${decodeW}x$decodeH -> 本地推理使用 ${targetW}x$targetH');
    
    // 转换为 RGB 像素数据
    final rgbBytes = Uint8List(targetW * targetH * 3);
    for (int y = 0; y < targetH; y++) {
      for (int x = 0; x < targetW; x++) {
        final pixel = resizedImage.getPixel(x, y);
        final index = (y * targetW + x) * 3;
        rgbBytes[index] = pixel.r.toInt();
        rgbBytes[index + 1] = pixel.g.toInt();
        rgbBytes[index + 2] = pixel.b.toInt();
      }
    }
    
    _log.info('LocalLlmService', 'RGB 像素数据: ${targetW}x$targetH -> ${rgbBytes.length} 字节');

    // 在后台 isolate 中执行同步 FFI 调用，避免阻塞主线程导致 ANR
    // 注意：isolate.kill(Immediate) 无法终止正在执行的 FFI 调用（Dart 限制），
    // 因此移除超时机制，让推理自然完成。
    final handleAddress = _handle!.address;
    _log.info('LocalLlmService', '在后台 isolate 中执行多模态推理 ... (maxTokens=$maxTokens, useGpu=${_config.useGpu}, threads=${_config.effectiveThreads}, ctx=${_config.contextSize})');
    final t0 = DateTime.now();

    final receivePort = ReceivePort();
    final args = _MultimodalIsolateArgs(
      sendPort: receivePort.sendPort,
      handleAddress: handleAddress,
      prompt: prompt,
      rgbBytes: rgbBytes,
      imageWidth: targetW,
      imageHeight: targetH,
      maxTokens: maxTokens,
      temperature: temperature,
    );

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_multimodalCompleteIsolateEntry, args);

      // 无超时等待 — isolate.kill 无法停止 FFI，超时只是徒增 CPU 空转
      final result = await receivePort.first;
      final t1 = DateTime.now();
      _log.info('LocalLlmService', '后台 isolate 多模态推理返回，耗时 ${t1.difference(t0).inMilliseconds}ms');
      if (result == null) {
        throw StateError('多模态推理失败 (返回 null)');
      }
      return result as String;
    } finally {
      receivePort.close();
      // 清理 isolate 外壳（FFI 若要跑完还是会跑完，但至少释放 Dart 侧资源）
      isolate?.kill(priority: Isolate.immediate);
    }
  }

  Uint8List _decodeBase64(String base64Str) {
    return Uint8List.fromList(base64Decode(base64Str));
  }

  @override
  void dispose() {
    // Stop: 标记已释放，拒绝新操作
    _disposed = true;
    debugPrint('[LocalLlmService] ${DateTime.now().toIso8601String()} dispose() - 标记已释放');

    // Await + Release: 串入操作队列，等待正在执行的 FFI 完成后关闭句柄
    _runSerialized(() async {
      if (_handle != null) {
        debugPrint('[LocalLlmService] ${DateTime.now().toIso8601String()} dispose() - 关闭模型句柄');
        _bindings.close(_handle!);
        _handle = null;
        debugPrint('[LocalLlmService] ${DateTime.now().toIso8601String()} dispose() 完成');
      }
    }, force: true);
  }
}

/// 在后台 isolate 中执行一次测试推理（加载模型 + 短推理 + 释放）
///
/// 返回推理结果字符串，失败返回 null。
/// 与旧版 [runTestInference] 不同，此方法不阻塞主线程。
Future<String?> runTestInferenceAsync({
  required String modelPath,
  String? mmprojPath,
  required int threads,
  required int contextSize,
  required String prompt,
  required int maxTokens,
  required double temperature,
}) async {
  debugPrint('[TestInference] 开始异步测试推理: $modelPath (threads=$threads, ctx=$contextSize)');

  final receivePort = ReceivePort();
  final args = _TextRunTestArgs(
    sendPort: receivePort.sendPort,
    modelPath: modelPath,
    mmprojPath: mmprojPath,
    threads: threads,
    contextSize: contextSize,
    prompt: prompt,
    maxTokens: maxTokens,
    temperature: temperature,
  );

  final t0 = DateTime.now();

  Isolate? isolate;
  try {
    isolate = await Isolate.spawn(_textRunTestInferenceIsolateEntry, args);
    final result = await receivePort.first;
    final t1 = DateTime.now();
    debugPrint('[TestInference] 异步测试推理完成，耗时 ${t1.difference(t0).inMilliseconds}ms, 结果: "$result"');
    return result as String?;
  } finally {
    receivePort.close();
    isolate?.kill(priority: Isolate.immediate);
  }
}
