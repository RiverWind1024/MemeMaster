import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';

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
  final String? extraParams;

  _InitIsolateArgs({
    required this.sendPort,
    required this.modelPath,
    this.mmprojPath,
    required this.threads,
    required this.contextSize,
    required this.useGpu,
    required this.nGpuLayers,
    this.logFilePath,
    this.extraParams,
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
    extraParams: args.extraParams,
  );
  args.sendPort.send(handle.address);
}

/// 可跨 isolate 传递的多模态推理参数
class _MultimodalIsolateArgs {
  final SendPort sendPort;
  final int handleAddress;
  final String messagesJson;
  final Uint8List rgbBytes;
  final int imageWidth;
  final int imageHeight;
  final int maxTokens;
  final double temperature;

  _MultimodalIsolateArgs({
    required this.sendPort,
    required this.handleAddress,
    required this.messagesJson,
    required this.rgbBytes,
    required this.imageWidth,
    required this.imageHeight,
    required this.maxTokens,
    required this.temperature,
  });
}

/// 在后台 isolate 中执行多模态对话推理（同步 FFI 调用，避免阻塞主线程 ANR）
///
/// 使用 mllm_multimodal_chat（含 chat template 和 mtmd 图片处理）。
void _multimodalChatIsolateEntry(_MultimodalIsolateArgs args) {
  final handle = Pointer<Void>.fromAddress(args.handleAddress);
  final bindings = NativeLlmBindings();
  final imageDataPtr = malloc<Uint8>(args.rgbBytes.length);
  imageDataPtr.asTypedList(args.rgbBytes.length).setAll(0, args.rgbBytes);
  try {
    final result = bindings.multimodalChat(
      handle,
      args.messagesJson,
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
  final LogService _log;
  Pointer<Void>? _handle;

  /// 标记服务已释放，拒绝新操作
  bool _disposed = false;

  /// Future-chain 操作序列化：所有 handle 操作排队执行，防止并发 FFI
  Completer<void>? _opCompleter;

  /// 模型加载期间的实时日志回调（由 UI 设置，用于显示加载日志）
  void Function(String logLines)? onLoadingLog;

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

  /// 创建本地 LLM 服务。
  /// [log] 必传，必须是全局共享的 LogService 实例（通过 logServiceProvider 拿到），
  /// 避免创建独立的 LogService 实例导致日志分散在不同内存缓冲区。
  /// 如果不传，会降级使用纯内存 LogService（仅用于向后兼容，不推荐）。
  LocalLlmService({
    required LocalLlmConfig config,
    LogService? log,
  })  : _config = config,
        _log = log ?? LogService();

  @override
  bool get isAvailable => _config.modelPath != null;

  /// 检查模型是否已加载（用于延迟加载）
  bool get isLoaded => _handle != null;

  /// 运行 C++ 端诊断：枚举所有可用后端、尝试 dlopen libOpenCL.so
  /// 不需要模型已加载。诊断结果会写入 mllm.log 文件
  /// 返回 0 成功，非 0 失败（-1 表示 FFI 不可用）
  int runDiagnostics() {
    return _bindings.runDiagnostics(logFilePath: _mllmLogFilePath);
  }

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
    _log.info('[LocalLlmService]', '开始加载模型: ${_config.modelPath} (threads=$effectiveThreads, ctx=${_config.contextSize})');

    final extraParams = _config.buildExtraParams();

    // 通过 Isolate 加载模型，避免阻塞主线程；带 60s 超时
    final receivePort = ReceivePort();
    final args = _InitIsolateArgs(
      sendPort: receivePort.sendPort,
      modelPath: _config.modelPath!,
      mmprojPath: _config.mmprojPath,
      threads: effectiveThreads,
      contextSize: _config.contextSize,
      useGpu: _config.useGpu ? 1 : 0,
      nGpuLayers: _config.useGpu ? _config.nGpuLayers : 0,
      logFilePath: _mllmLogFilePath,
      extraParams: extraParams,
    );

    Isolate? isolate;
    Timer? logTimer;
    int logSinceId = 0;
    try {
      isolate = await Isolate.spawn(_initIsolateEntry, args);

      // 加载期间轮询 C++ 日志环形缓冲区（每 500ms），通过回调通知 UI
      logTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        final (logs, lastId) = _bindings.getLogs(sinceId: logSinceId);
        if (logs.isNotEmpty) {
          logSinceId = lastId;
          onLoadingLog?.call(logs);
        }
      });

      final address = await receivePort.first.timeout(const Duration(seconds: 60));
      logTimer.cancel();
      if (address == 0) {
        throw StateError('模型加载失败: ${_config.modelPath}');
      }
      _handle = Pointer<Void>.fromAddress(address as int);
      final t1 = DateTime.now();
      _log.info('[LocalLlmService]', '模型加载完成，耗时 ${t1.difference(t0).inMilliseconds}ms');
    } on TimeoutException {
      isolate?.kill(priority: Isolate.immediate);
      logTimer?.cancel();
      debugPrint('[LocalLlmService] 模型加载超时 (60s): ${_config.modelPath}');
      throw StateError('模型加载超时 (60s): ${_config.modelPath}');
    } finally {
      logTimer?.cancel();
      receivePort.close();
    }
  }

  @override
  Future<String> complete(
    String prompt, {
    LlmOptions? options,
  }) async {
    throw UnsupportedError(
      'LocalLlmService 不支持纯文本 complete(),'
      '请使用 vision_enricher 或 chat(messages) 并附带图片',
    );
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  }) async {
    return _runSerialized(() async {
      await _ensureLoaded();

      final maxTokens = options?.maxTokens ?? 512;
      final temperature = options?.temperature ?? 0.7;
      final imageMsg = messages.firstWhere(
        (m) => m.imageBase64 != null || m.imageBytes != null,
        orElse: () => throw StateError('LocalLlmService.chat 要求至少一条消息包含图片'),
      );

      // 构建 messages JSON，有图片的消息 content 前加 <__media__> 标记
      // mtmd_tokenize 识别 <__media__> 后将其替换为图片 embedding
      final jsonArray = jsonEncode(messages.map((m) {
        var content = m.content;
        if (m.imageBase64 != null || m.imageBytes != null) {
          content = '<__media__>\n$content';
        }
        return {'role': m.role, 'content': content};
      }).toList());
      _log.info('LocalLlmService', '调用多模态对话推理，messages=${messages.length}');

      // 优先使用原始字节（本地 LLM），否则回退到 base64（远程 API）
      if (imageMsg.imageBytes != null) {
        return _multimodalChatWithBytes(jsonArray, imageMsg.imageBytes!, maxTokens, temperature);
      }
      return _multimodalChat(jsonArray, imageMsg.imageBase64!, maxTokens, temperature);
    });
  }

  Future<String> _multimodalChat(
    String messagesJson,
    String base64Image,
    int maxTokens,
    double temperature,
  ) async {
    final imageBytes = _decodeBase64(base64Image);
    return _multimodalChatWithBytes(messagesJson, imageBytes, maxTokens, temperature);
  }

  Future<String> _multimodalChatWithBytes(
    String messagesJson,
    Uint8List imageBytes,
    int maxTokens,
    double temperature,
  ) async {
    final t0 = DateTime.now();
    final decodedImage = img.decodeImage(imageBytes);
    final t1 = DateTime.now();
    if (decodedImage == null) {
      throw StateError('无法解码图片');
    }
    final pixelCount = decodedImage.width * decodedImage.height;
    if (pixelCount > 1024 * 1024) {
      _log.warning('LocalLlmService', '图片过大 (${decodedImage.width}x${decodedImage.height})，可能导致内存不足');
    }
    final decodeW = decodedImage.width;
    final decodeH = decodedImage.height;
    final (targetW, targetH, resizedImage) = () {
      if (!_config.imageCompressionEnabled) {
        _log.info('LocalLlmService', '图片压缩已关闭，使用原始尺寸 ${decodeW}x$decodeH (图片解码耗时 ${t1.difference(t0).inMilliseconds}ms)');
        return (decodeW, decodeH, decodedImage);
      }
      const int maxLocalDim = 384;
      if (decodeW > maxLocalDim || decodeH > maxLocalDim) {
        final t2 = DateTime.now();
        final result = _resizeKeepingAspectRatio(decodedImage, maxLocalDim);
        final t3 = DateTime.now();
        _log.info('LocalLlmService', '图片压缩: ${decodeW}x$decodeH -> ${result.$1}x${result.$2} (解码=${t1.difference(t0).inMilliseconds}ms, 缩放=${t3.difference(t2).inMilliseconds}ms)');
        return result;
      }
      _log.info('LocalLlmService', '图片无需压缩: ${decodeW}x$decodeH (解码耗时 ${t1.difference(t0).inMilliseconds}ms)');
      return (decodeW, decodeH, decodedImage);
    }();
    
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

    final handleAddress = _handle!.address;
    _log.info('LocalLlmService', '在后台 isolate 中执行多模态对话推理 ... (maxTokens=$maxTokens)');
    final tInfer = DateTime.now();

    final receivePort = ReceivePort();
    final args = _MultimodalIsolateArgs(
      sendPort: receivePort.sendPort,
      handleAddress: handleAddress,
      messagesJson: messagesJson,
      rgbBytes: rgbBytes,
      imageWidth: targetW,
      imageHeight: targetH,
      maxTokens: maxTokens,
      temperature: temperature,
    );

    Isolate? isolate;
    try {
      isolate = await Isolate.spawn(_multimodalChatIsolateEntry, args);

      final result = await receivePort.first;
      final t1 = DateTime.now();
      _log.info('LocalLlmService', '后台 isolate 多模态对话推理返回，耗时 ${t1.difference(tInfer).inMilliseconds}ms');
      if (result == null) {
        throw StateError('多模态对话推理失败 (返回 null)');
      }
      final resultStr = result as String;
      // 日志输出结果前 300 字符，便于调试
      final preview = resultStr.length > 300 ? '${resultStr.substring(0, 300)}...' : resultStr;
      _log.info('LocalLlmService', '多模态推理结果 (${resultStr.length} 字符): $preview');
      return resultStr;
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
