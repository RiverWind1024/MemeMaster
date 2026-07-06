import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef MllmInitC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Int32, Int32, Int32, Pointer<Utf8>, Pointer<Utf8>);
typedef MllmInitDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int, int, int, int, Pointer<Utf8>, Pointer<Utf8>);

typedef MllmGetLogsC = Pointer<Utf8> Function(Uint64, Pointer<Uint64>);
typedef MllmGetLogsDart = Pointer<Utf8> Function(int, Pointer<Uint64>);

typedef MllmCompleteC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, Int32, Float);
typedef MllmCompleteDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>, int, double);

typedef MllmMultimodalCompleteC = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, Uint64, Int32, Int32, Int32, Float);
typedef MllmMultimodalCompleteDart = Pointer<Utf8> Function(
    Pointer<Void>, Pointer<Utf8>, Pointer<Uint8>, int, int, int, int, double);

typedef MllmCloseC = Void Function(Pointer<Void>);
typedef MllmCloseDart = void Function(Pointer<Void>);

typedef MllmFreeStringC = Void Function(Pointer<Utf8>);
typedef MllmFreeStringDart = void Function(Pointer<Utf8>);

// Streaming API
typedef MllmTokenCallbackC = Int32 Function(Pointer<Utf8>, Pointer<Void>);
typedef MllmTokenCallbackDart = int Function(Pointer<Utf8>, Pointer<Void>);

typedef MllmCompleteStreamC = Int32 Function(
    Pointer<Void>, Pointer<Utf8>, Int32, Float, Pointer<NativeFunction<MllmTokenCallbackC>>, Pointer<Void>);
typedef MllmCompleteStreamDart = int Function(
    Pointer<Void>, Pointer<Utf8>, int, double, Pointer<NativeFunction<MllmTokenCallbackC>>, Pointer<Void>);

class NativeLlmBindings {
  DynamicLibrary? _dylib;

  MllmInitDart? mllmInit;
  MllmCompleteDart? mllmComplete;
  MllmMultimodalCompleteDart? mllmMultimodalComplete;
  MllmCloseDart? mllmClose;
  MllmFreeStringDart? mllmFreeString;
  MllmCompleteStreamDart? mllmCompleteStream;
  MllmGetLogsDart? mllmGetLogs;

  /// 构造函数尝试加载动态库，捕获异常避免闪退
  NativeLlmBindings() {
    try {
      _dylib = DynamicLibrary.open('libmeme_llm.so');
      mllmInit = _dylib!.lookupFunction<MllmInitC, MllmInitDart>('mllm_init');
      mllmComplete = _dylib!.lookupFunction<MllmCompleteC, MllmCompleteDart>('mllm_complete');
      mllmMultimodalComplete =
          _dylib!.lookupFunction<MllmMultimodalCompleteC, MllmMultimodalCompleteDart>(
              'mllm_multimodal_complete');
      mllmClose = _dylib!.lookupFunction<MllmCloseC, MllmCloseDart>('mllm_close');
      mllmFreeString = _dylib!.lookupFunction<MllmFreeStringC, MllmFreeStringDart>('mllm_free_string');
      mllmCompleteStream =
          _dylib!.lookupFunction<MllmCompleteStreamC, MllmCompleteStreamDart>('mllm_complete_stream');
      mllmGetLogs = _dylib!.lookupFunction<MllmGetLogsC, MllmGetLogsDart>('mllm_get_logs');
    } catch (e) {
      // 加载失败时不抛异常，后续调用通过 mllmInit==null 判断不可用
      // 防止因 ABI 不匹配或 .so 缺失导致 app 启动时直接闪退
    }
  }

  bool get isLoaded => _dylib != null;

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

  String? complete(Pointer<Void> handle, String prompt, int maxTokens, double temperature) {
    final fn = mllmComplete!;
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = fn(handle, promptPtr, maxTokens, temperature);
    malloc.free(promptPtr);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    mllmFreeString!(resultPtr);
    return result;
  }

  String? multimodalComplete(
    Pointer<Void> handle,
    String prompt,
    Pointer<Uint8> imageData,
    int imageDataSize,
    int imageWidth,
    int imageHeight,
    int maxTokens,
    double temperature,
  ) {
    final fn = mllmMultimodalComplete!;
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = fn(
        handle, promptPtr, imageData, imageDataSize, imageWidth, imageHeight, maxTokens, temperature);
    malloc.free(promptPtr);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    mllmFreeString!(resultPtr);
    return result;
  }

  void close(Pointer<Void> handle) {
    mllmClose!(handle);
  }

  /// 流式补全：通过 callback 逐 token 接收结果
  /// 返回 0 成功，非 0 失败
  int completeStream(
    Pointer<Void> handle,
    String prompt,
    int maxTokens,
    double temperature,
    Pointer<NativeFunction<MllmTokenCallbackC>> callback,
    Pointer<Void> userData,
  ) {
    final fn = mllmCompleteStream!;
    final promptPtr = prompt.toNativeUtf8();
    final result = fn(handle, promptPtr, maxTokens, temperature, callback, userData);
    malloc.free(promptPtr);
    return result;
  }
}
