import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

typedef MllmInitC = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, Int32, Int32);
typedef MllmInitDart = Pointer<Void> Function(Pointer<Utf8>, Pointer<Utf8>, int, int);

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

class NativeLlmBindings {
  late final DynamicLibrary _dylib;

  late final MllmInitDart mllmInit;
  late final MllmCompleteDart mllmComplete;
  late final MllmMultimodalCompleteDart mllmMultimodalComplete;
  late final MllmCloseDart mllmClose;
  late final MllmFreeStringDart mllmFreeString;

  NativeLlmBindings() {
    _dylib = Platform.isAndroid
        ? DynamicLibrary.open('libmeme_llm.so')
        : DynamicLibrary.open('libmeme_llm.so');

    mllmInit = _dylib.lookupFunction<MllmInitC, MllmInitDart>('mllm_init');
    mllmComplete = _dylib.lookupFunction<MllmCompleteC, MllmCompleteDart>('mllm_complete');
    mllmMultimodalComplete =
        _dylib.lookupFunction<MllmMultimodalCompleteC, MllmMultimodalCompleteDart>(
            'mllm_multimodal_complete');
    mllmClose = _dylib.lookupFunction<MllmCloseC, MllmCloseDart>('mllm_close');
    mllmFreeString = _dylib.lookupFunction<MllmFreeStringC, MllmFreeStringDart>('mllm_free_string');
  }

  Pointer<Void> init(String modelPath, String? mmprojPath, int threads, int ctxSize) {
    final modelPtr = modelPath.toNativeUtf8();
    final mmprojPtr = mmprojPath?.toNativeUtf8() ?? nullptr;
    final handle = mllmInit(modelPtr, mmprojPtr, threads, ctxSize);
    malloc.free(modelPtr);
    if (mmprojPath != null) malloc.free(mmprojPtr);
    return handle;
  }

  String? complete(Pointer<Void> handle, String prompt, int maxTokens, double temperature) {
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = mllmComplete(handle, promptPtr, maxTokens, temperature);
    malloc.free(promptPtr);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    mllmFreeString(resultPtr);
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
    final promptPtr = prompt.toNativeUtf8();
    final resultPtr = mllmMultimodalComplete(
        handle, promptPtr, imageData, imageDataSize, imageWidth, imageHeight, maxTokens, temperature);
    malloc.free(promptPtr);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    mllmFreeString(resultPtr);
    return result;
  }

  void close(Pointer<Void> handle) {
    mllmClose(handle);
  }
}
