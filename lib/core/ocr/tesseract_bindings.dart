import 'dart:ffi';
import 'dart:io' show Platform, Directory, File;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../services/log_service.dart';

final _log = LogService();

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
      // Platform.resolvedExecutable 在 Flutter macOS app 中指向 Flutter engine
      // (FlutterMacOS.framework/Versions/.../FlutterMacOS)，不是 app 的 MacOS 目录
      // 因此需要向上找到 Contents/Frameworks/
      String exePath = Platform.resolvedExecutable;
      // 向上遍历直到找到 Frameworks 目录
      for (int i = 0; i < 10; i++) {
        final parent = path.dirname(exePath);
        if (parent == exePath) break; // reached root
        final frameworksPath = path.join(parent, 'Frameworks');
        if (Directory(frameworksPath).existsSync()) {
          return frameworksPath;
        }
        exePath = parent;
      }
      // Fallback: 尝试从 MacOS 子目录计算 (app bundle 标准结构)
      // AppName.app/Contents/MacOS/executable -> AppName.app/Contents/Frameworks/
      final exeDir = path.dirname(Platform.resolvedExecutable);
      return path.join(path.dirname(path.dirname(exeDir)), 'Frameworks');
    } catch (e) {
      return null;
    }
  }

  /// 获取 tessdata 目录路径
  /// macOS: App.app/Contents/Resources/tessdata/
  /// Linux: bundle/share/tessdata/ 或 bundle/tessdata/
  static String getTessdataPath() {
    try {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      if (Platform.isMacOS) {
        // macOS: 向上找到 Contents/Resources/tessdata/
        // Platform.resolvedExecutable 指向 Flutter engine，不在 MacOS 子目录
        String exePath = Platform.resolvedExecutable;
        for (int i = 0; i < 10; i++) {
          final parent = path.dirname(exePath);
          if (parent == exePath) break;
          final resourcesPath = path.join(parent, 'Resources', 'tessdata');
          if (Directory(resourcesPath).existsSync()) {
            return resourcesPath;
          }
          exePath = parent;
        }
        // Fallback: AppName.app/Contents/MacOS/executable -> Contents/Resources/tessdata
        return path.join(path.dirname(path.dirname(path.dirname(exeDir))), 'Resources', 'tessdata');
      } else if (Platform.isLinux) {
        // Linux: 同级目录下的 share/tessdata/ 或 tessdata/
        final resourcesPath = path.join(exeDir, 'share', 'tessdata');
        if (Directory(resourcesPath).existsSync()) {
          return resourcesPath;
        }
        // 备用: bundle/tessdata/
        return path.join(exeDir, 'tessdata');
      } else if (Platform.isWindows) {
        // Windows: exe 同级的 tessdata/
        return path.join(exeDir, 'tessdata');
      }
    } catch (e) {
      // ignore
    }
    return '';
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
    // Debug output - write to /tmp file since LogService might crash
    final debugInfo = StringBuffer();
    debugInfo.writeln('resolvedExecutable: ${Platform.resolvedExecutable}');
    debugInfo.writeln('Frameworks path: ${_getMacOSFrameworksPath()}');
    debugInfo.writeln('tessdata path: ${getTessdataPath()}');
    debugInfo.writeln('Candidates:');
    for (final c in candidates) {
      debugInfo.writeln('  $c');
    }
    debugInfo.writeln('Loaded: $_isLoaded');
    // Write to file for debugging
    try {
      File('/tmp/ocr_tess_debug.txt').writeAsStringSync(debugInfo.toString());
    } catch (e) {
      // ignore
    }
    // Also try LogService
    try {
      _log.warning('OCR', 'FFI dylib debug: ${debugInfo.toString()}');
    } catch (_) {}
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
