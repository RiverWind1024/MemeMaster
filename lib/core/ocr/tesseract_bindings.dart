import 'dart:ffi';
import 'dart:io' show Platform;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef TessCreateC = Pointer<Void> Function();
typedef TessCreateDart = Pointer<Void> Function();

typedef TessDestroyC = Void Function(Pointer<Void>);
typedef TessDestroyDart = void Function(Pointer<Void>);

typedef TessInitC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef TessInitDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef TessEndC = Void Function(Pointer<Void>);
typedef TessEndDart = void Function(Pointer<Void>);

typedef TessSetImageFileC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef TessSetImageFileDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef TessGetUtf8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef TessGetUtf8TextDart = Pointer<Utf8> Function(Pointer<Void>);

typedef TessFreeTextC = Void Function(Pointer<Utf8>);
typedef TessFreeTextDart = void Function(Pointer<Utf8>);

typedef TessVersionC = Pointer<Utf8> Function();
typedef TessVersionDart = Pointer<Utf8> Function();

class TessOcrBindings {
  DynamicLibrary? _dylib;

  TessCreateDart? tessCreate;
  TessDestroyDart? tessDestroy;
  TessInitDart? tessInit;
  TessEndDart? tessEnd;
  TessSetImageFileDart? tessSetImageFile;
  TessGetUtf8TextDart? tessGetUtf8Text;
  TessFreeTextDart? tessFreeText;
  TessVersionDart? tessVersion;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 获取 macOS app bundle 中的 Frameworks 目录路径
  String? _getMacOSFrameworksPath() {
    try {
      // 获取可执行文件路径
      final exePath = path.dirname(Platform.resolvedExecutable);
      // macOS app bundle 结构: AppName.app/Contents/MacOS/executable
      // 我们需要: AppName.app/Contents/Frameworks/
      final frameworksPath = path.join(
        path.dirname(path.dirname(exePath)), // .. → Contents
        'Frameworks'
      );
      return frameworksPath;
    } catch (e) {
      return null;
    }
  }

  TessOcrBindings() {
    final candidates = <String>[];

    if (Platform.isLinux) {
      candidates.addAll([
        'libtesseract_ocr.so',
        'libtesseract_ocr.so.1',
        'libleptonica.so',
        'libleptonica.so.1',
      ]);
    } else if (Platform.isMacOS) {
      // 首先尝试 app bundle 中的 Frameworks 目录
      final fwPath = _getMacOSFrameworksPath();
      if (fwPath != null) {
        candidates.addAll([
          '$fwPath/libtesseract_ocr.dylib',
          '$fwPath/libtesseract.dylib',
          '$fwPath/libleptonica.dylib',
        ]);
      }
      // 然后尝试系统路径
      candidates.addAll([
        'libtesseract_ocr.dylib',
        'libtesseract.dylib',
        'libleptonica.dylib',
      ]);
    } else if (Platform.isWindows) {
      candidates.addAll([
        'libtesseract-5.dll',
        'tesseract-5.dll',
        'tesseract.dll',
      ]);
    }

    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLoaded = true;
        _bindFunctions();
        break;
      } catch (e) {
        _dylib = null;
        _isLoaded = false;
      }
    }
  }

  void _bindFunctions() {
    if (_dylib == null) return;

    tessCreate = _dylib!.lookupFunction<TessCreateC, TessCreateDart>('tess_create');
    tessDestroy = _dylib!.lookupFunction<TessDestroyC, TessDestroyDart>('tess_destroy');
    tessInit = _dylib!.lookupFunction<TessInitC, TessInitDart>('tess_init');
    tessEnd = _dylib!.lookupFunction<TessEndC, TessEndDart>('tess_end');
    tessSetImageFile = _dylib!.lookupFunction<TessSetImageFileC, TessSetImageFileDart>('tess_set_image_file');
    tessGetUtf8Text = _dylib!.lookupFunction<TessGetUtf8TextC, TessGetUtf8TextDart>('tess_get_utf8_text');
    tessFreeText = _dylib!.lookupFunction<TessFreeTextC, TessFreeTextDart>('tess_free_text');
    tessVersion = _dylib!.lookupFunction<TessVersionC, TessVersionDart>('tess_version');
  }

  Pointer<Void> create() => tessCreate!();

  void destroy(Pointer<Void> handle) => tessDestroy!(handle);

  int init(Pointer<Void> handle, String datapath, String language) {
    final datapathPtr = datapath.toNativeUtf8();
    final langPtr = language.toNativeUtf8();
    final result = tessInit!(handle, datapathPtr, langPtr);
    malloc.free(datapathPtr);
    malloc.free(langPtr);
    return result;
  }

  void end(Pointer<Void> handle) => tessEnd!(handle);

  int setImageFile(Pointer<Void> handle, String filename) {
    final filenamePtr = filename.toNativeUtf8();
    final result = tessSetImageFile!(handle, filenamePtr);
    malloc.free(filenamePtr);
    return result;
  }

  String? getUtf8Text(Pointer<Void> handle) {
    final resultPtr = tessGetUtf8Text!(handle);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    tessFreeText!(resultPtr);
    return result;
  }

  String? getVersion() {
    if (tessVersion == null) return null;
    final resultPtr = tessVersion!();
    if (resultPtr == nullptr) return null;
    return resultPtr.toDartString();
  }
}
