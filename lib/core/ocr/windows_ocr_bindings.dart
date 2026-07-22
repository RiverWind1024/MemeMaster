import 'dart:ffi';
import 'dart:io' show Platform, Directory, File;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../services/log_service.dart';

LogService? _logInstance;
LogService _getLog() => _logInstance ??= LogService.instance;

typedef OcrCreateC = Pointer<Void> Function();
typedef OcrCreateDart = Pointer<Void> Function();

typedef OcrDestroyC = Void Function(Pointer<Void>);
typedef OcrDestroyDart = void Function(Pointer<Void>);

typedef OcrRecognizeC = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);
typedef OcrRecognizeDart = Pointer<Utf8> Function(Pointer<Void>, Pointer<Utf8>);

typedef OcrFreeResultC = Void Function(Pointer<Utf8>);
typedef OcrFreeResultDart = void Function(Pointer<Utf8>);

typedef OcrVersionC = Pointer<Utf8> Function();
typedef OcrVersionDart = Pointer<Utf8> Function();

class WindowsOcrBindings {
  DynamicLibrary? _dylib;

  OcrCreateDart? ocrCreate;
  OcrDestroyDart? ocrDestroy;
  OcrRecognizeDart? ocrRecognize;
  OcrFreeResultDart? ocrFreeResult;
  OcrVersionDart? ocrVersion;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  String? _getDllPath() {
    if (!Platform.isWindows) return null;
    try {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      return path.join(exeDir, 'windows_ocr.dll');
    } catch (_) {
      return null;
    }
  }

  WindowsOcrBindings() {
    if (!Platform.isWindows) return;

    final candidates = <String>[
      'windows_ocr.dll',
    ];

    final dllPath = _getDllPath();
    if (dllPath != null) {
      candidates.insert(0, dllPath);
    }

    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLoaded = true;
        _bindFunctions();
        _getLog().info('OCR', 'Windows OCR DLL loaded: $name');
        break;
      } catch (e) {
        _dylib = null;
        _isLoaded = false;
        _getLog().info('OCR', 'Windows OCR DLL failed: $name - $e');
      }
    }
  }

  void _bindFunctions() {
    if (_dylib == null) return;

    ocrCreate = _dylib!.lookupFunction<OcrCreateC, OcrCreateDart>('ocr_create');
    ocrDestroy = _dylib!.lookupFunction<OcrDestroyC, OcrDestroyDart>('ocr_destroy');
    ocrRecognize = _dylib!.lookupFunction<OcrRecognizeC, OcrRecognizeDart>('ocr_recognize');
    ocrFreeResult = _dylib!.lookupFunction<OcrFreeResultC, OcrFreeResultDart>('ocr_free_result');
    ocrVersion = _dylib!.lookupFunction<OcrVersionC, OcrVersionDart>('ocr_version');
  }

  Pointer<Void> create() => ocrCreate!();

  void destroy(Pointer<Void> handle) => ocrDestroy!(handle);

  String? recognize(Pointer<Void> handle, String imagePath) {
    final pathPtr = imagePath.toNativeUtf8();
    final resultPtr = ocrRecognize!(handle, pathPtr);
    malloc.free(pathPtr);

    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    ocrFreeResult!(resultPtr);
    return result;
  }

  String? getVersion() {
    if (ocrVersion == null) return null;
    final resultPtr = ocrVersion!();
    if (resultPtr == nullptr) return null;
    return resultPtr.toDartString();
  }
}
