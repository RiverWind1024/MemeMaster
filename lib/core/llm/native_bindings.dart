import 'dart:ffi';
import 'package:ffi/ffi.dart';

typedef MllmInitC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Int32, Int32, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef MllmInitDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int, int, int, int, Pointer<Utf8>, Pointer<Utf8>);

typedef MllmGetLogsC = Pointer<Utf8> Function(Uint64, Pointer<Uint64>);
typedef MllmGetLogsDart = Pointer<Utf8> Function(int, Pointer<Uint64>);

typedef MllmIsMtmdLoadedC = Int32 Function(Pointer<Void>);
typedef MllmIsMtmdLoadedDart = int Function(Pointer<Void>);

typedef MllmMultimodalChatC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, Uint64, Int32, Int32, Int32, Float);
typedef MllmMultimodalChatDart = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int, int, int, int, double);

typedef MllmCloseC = Void Function(Pointer<Void>);
typedef MllmCloseDart = void Function(Pointer<Void>);

typedef MllmFreeStringC = Void Function(Pointer<Utf8>);
typedef MllmFreeStringDart = void Function(Pointer<Utf8>);

typedef MllmRunDiagnosticsC = Int32 Function(Pointer<Utf8>);
typedef MllmRunDiagnosticsDart = int Function(Pointer<Utf8>);

class NativeLlmBindings {
  DynamicLibrary? _dylib;

  MllmInitDart? mllmInit;
  MllmMultimodalChatDart? mllmMultimodalChat;
  MllmCloseDart? mllmClose;
  MllmFreeStringDart? mllmFreeString;
  MllmGetLogsDart? mllmGetLogs;
  MllmIsMtmdLoadedDart? mllmIsMtmdLoaded;
  MllmRunDiagnosticsDart? mllmRunDiagnostics;

  /// 构造函数尝试加载动态库，捕获异常避免闪退
  NativeLlmBindings() {
    // 优先加载完整版，失败则回退到 stub
    final candidates = ['libmeme_llm.so', 'libmeme_llm_empty.so'];
    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isStub = name.contains('empty');
        mllmInit = _dylib!.lookupFunction<MllmInitC, MllmInitDart>('mllm_init');
        mllmMultimodalChat =
            _dylib!.lookupFunction<MllmMultimodalChatC, MllmMultimodalChatDart>(
                'mllm_multimodal_chat');
        mllmClose = _dylib!.lookupFunction<MllmCloseC, MllmCloseDart>('mllm_close');
        mllmFreeString = _dylib!.lookupFunction<MllmFreeStringC, MllmFreeStringDart>('mllm_free_string');
        mllmGetLogs = _dylib!.lookupFunction<MllmGetLogsC, MllmGetLogsDart>('mllm_get_logs');
        mllmIsMtmdLoaded = _dylib!.lookupFunction<MllmIsMtmdLoadedC, MllmIsMtmdLoadedDart>('mllm_is_mtmd_loaded');
        mllmRunDiagnostics = _dylib!.lookupFunction<MllmRunDiagnosticsC, MllmRunDiagnosticsDart>('mllm_run_diagnostics');
        break;
      } catch (e) {
        _dylib = null;
        _isStub = false;
        mllmInit = null;
        mllmMultimodalChat = null;
        mllmClose = null;
        mllmFreeString = null;
        mllmGetLogs = null;
        mllmIsMtmdLoaded = null;
        mllmRunDiagnostics = null;
      }
    }
  }

  bool _isStub = false;
  bool get isLoaded => _dylib != null;
  bool get isStub => _isStub;

  Pointer<Void> init(
    String modelPath,
    String? mmprojPath,
    int threads,
    int ctxSize, {
    int useGpu = 1,
    int nGpuLayers = -1,
    String? logFilePath,
    String? extraParams,
  }) {
    final fn = mllmInit!;
    final modelPtr = modelPath.toNativeUtf8();
    final mmprojPtr = mmprojPath?.toNativeUtf8() ?? nullptr;
    final logPtr = logFilePath?.toNativeUtf8() ?? nullptr;
    final extraPtr = extraParams?.toNativeUtf8() ?? nullptr;
    final handle = fn(modelPtr, mmprojPtr, threads, ctxSize, useGpu, nGpuLayers, logPtr, extraPtr);
    malloc.free(modelPtr);
    if (mmprojPath != null) malloc.free(mmprojPtr);
    if (logFilePath != null) malloc.free(logPtr);
    if (extraParams != null) malloc.free(extraPtr);
    return handle;
  }

  /// 增量获取 C++ 侧捕获的最近日志，返回 (日志文本, 最后一条日志的ID)
  /// 首次调用传 sinceId=0，后续传入上次返回的 lastId 做增量读取
  (String logs, int lastId) getLogs({int sinceId = 0}) {
    final fn = mllmGetLogs;
    if (fn == null) return ('', 0);
    final lastIdPtr = malloc<Uint64>();
    lastIdPtr.value = 0;
    final resultPtr = fn(sinceId, lastIdPtr);
    final lastId = lastIdPtr.value;
    malloc.free(lastIdPtr);
    if (resultPtr == nullptr) return ('', lastId);
    final result = resultPtr.toDartString();
    mllmFreeString!(resultPtr);
    return (result, lastId);
  }

  bool isMtmdLoaded(Pointer<Void> handle) {
    final fn = mllmIsMtmdLoaded;
    if (fn == null) return false;
    return fn(handle) != 0;
  }

  /// 运行 C++ 端诊断（枚举所有后端、尝试 dlopen libOpenCL.so 等）
  /// logFilePath: 把诊断输出写入此文件，传 null 则只写 logcat
  /// 返回 0 成功，非 0 失败
  int runDiagnostics({String? logFilePath}) {
    final fn = mllmRunDiagnostics;
    if (fn == null) return -1;
    final logPtr = logFilePath?.toNativeUtf8() ?? nullptr;
    final ret = fn(logPtr);
    if (logFilePath != null) malloc.free(logPtr);
    return ret;
  }

  /// 多模态对话：传入 JSON 消息列表 + RGB 图片数据，使用 chat template 格式化
  /// messagesJson 中带图片的消息 content 须包含 <__media__> 标记
  String? multimodalChat(
    Pointer<Void> handle,
    String messagesJson,
    Pointer<Uint8> imageData,
    int imageDataSize,
    int imageWidth,
    int imageHeight,
    int maxTokens,
    double temperature,
  ) {
    final fn = mllmMultimodalChat!;
    final jsonPtr = messagesJson.toNativeUtf8();
    final resultPtr = fn(
        handle, jsonPtr, imageData, imageDataSize, imageWidth, imageHeight, maxTokens, temperature);
    malloc.free(jsonPtr);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    mllmFreeString!(resultPtr);
    return result;
  }

  void close(Pointer<Void> handle) {
    mllmClose!(handle);
  }
}
