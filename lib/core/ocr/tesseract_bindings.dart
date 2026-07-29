import 'dart:ffi';
import 'dart:io' show Platform, Directory;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

import '../../services/log_service.dart';

LogService? _logInstance;
LogService _getLog() => _logInstance ??= LogService.instance;

// ============= Linux 封装 API 类型 =============
typedef LinuxTessCreateC = Pointer<Void> Function();
typedef LinuxTessCreateDart = Pointer<Void> Function();

typedef LinuxTessDestroyC = Void Function(Pointer<Void>);
typedef LinuxTessDestroyDart = void Function(Pointer<Void>);

typedef LinuxTessInitC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef LinuxTessInitDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef LinuxTessEndC = Void Function(Pointer<Void>);
typedef LinuxTessEndDart = void Function(Pointer<Void>);

typedef LinuxTessSetImageFileC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef LinuxTessSetImageFileDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef LinuxTessGetUtf8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef LinuxTessGetUtf8TextDart = Pointer<Utf8> Function(Pointer<Void>);

typedef LinuxTessFreeTextC = Void Function(Pointer<Utf8>);
typedef LinuxTessFreeTextDart = void Function(Pointer<Utf8>);

typedef LinuxTessVersionC = Pointer<Utf8> Function();
typedef LinuxTessVersionDart = Pointer<Utf8> Function();

typedef LinuxTessSetVariableC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef LinuxTessSetVariableDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

// ============= Windows 原生 API 类型 =============
typedef WinTessBaseAPICreateC = Pointer<Void> Function();
typedef WinTessBaseAPICreateDart = Pointer<Void> Function();

typedef WinTessBaseAPIDeleteC = Void Function(Pointer<Void>);
typedef WinTessBaseAPIDeleteDart = void Function(Pointer<Void>);

typedef WinTessBaseAPIInit3C = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef WinTessBaseAPIInit3Dart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef WinTessBaseAPIEndC = Void Function(Pointer<Void>);
typedef WinTessBaseAPIEndDart = void Function(Pointer<Void>);

// TessBaseAPISetImage2 - 使用 Pix* 结构设置图像
typedef WinTessBaseAPISetImage2C = Void Function(Pointer<Void>, Pointer<Void>);
typedef WinTessBaseAPISetImage2Dart = void Function(Pointer<Void>, Pointer<Void>);

// TessBaseAPIGetUTF8Text 返回识别的 UTF-8 文本
typedef WinTessBaseAPIGetUTF8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef WinTessBaseAPIGetUTF8TextDart = Pointer<Utf8> Function(Pointer<Void>);

// TessBaseAPIDeleteText 释放 GetUTF8Text 返回的内存
typedef WinTessBaseAPIDeleteTextC = Void Function(Pointer<Utf8>);
typedef WinTessBaseAPIDeleteTextDart = void Function(Pointer<Utf8>);

// TessVersion 返回版本字符串
typedef WinTessVersionC = Pointer<Utf8> Function();
typedef WinTessVersionDart = Pointer<Utf8> Function();

// TessBaseAPISetVariable 设置 OCR 参数
typedef WinTessBaseAPISetVariableC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef WinTessBaseAPISetVariableDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

// ============= Leptonica API 类型 (Windows) =============
// Pix* pixRead(const char *filename);
typedef PixReadC = Pointer<Void> Function(Pointer<Utf8>);
typedef PixReadDart = Pointer<Void> Function(Pointer<Utf8>);

// void pixDestroy(Pix** pix);
typedef PixDestroyC = Void Function(Pointer<Pointer<Void>>);
typedef PixDestroyDart = void Function(Pointer<Pointer<Void>>);

class TessOcrBindings {
  DynamicLibrary? _dylib;
  DynamicLibrary? _leptonicaLib;
  bool _isLinux = false;

  // Linux 封装 API
  LinuxTessCreateDart? _linuxCreate;
  LinuxTessDestroyDart? _linuxDestroy;
  LinuxTessInitDart? _linuxInit;
  LinuxTessEndDart? _linuxEnd;
  LinuxTessSetImageFileDart? _linuxSetImageFile;
  LinuxTessGetUtf8TextDart? _linuxGetUtf8Text;
  LinuxTessFreeTextDart? _linuxFreeText;
  LinuxTessVersionDart? _linuxVersion;
  LinuxTessSetVariableDart? _linuxSetVariable;

  // Windows 原生 API
  WinTessBaseAPICreateDart? _winCreate;
  WinTessBaseAPIDeleteDart? _winDelete;
  WinTessBaseAPIInit3Dart? _winInit;
  WinTessBaseAPIEndDart? _winEnd;
  WinTessBaseAPISetImage2Dart? _winSetImage2;
  WinTessBaseAPIGetUTF8TextDart? _winGetUtf8Text;
  WinTessBaseAPIDeleteTextDart? _winDeleteText;
  WinTessVersionDart? _winVersion;
  WinTessBaseAPISetVariableDart? _winSetVariable;

  // Leptonica (Windows)
  PixReadDart? _pixRead;
  PixDestroyDart? _pixDestroy;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  /// 静态方法检测 FFI 是否已加载（跨库访问用）
  static bool get ffiIsLoaded => _instance?._isLoaded ?? false;

  /// 单例实例
  static TessOcrBindings? _instance;

  static String getTessdataPath() {
    try {
      final exeDir = path.dirname(Platform.resolvedExecutable);
      if (Platform.isLinux) {
        final resourcesPath = path.join(exeDir, 'share', 'tessdata');
        if (Directory(resourcesPath).existsSync()) {
          return resourcesPath;
        }
        return path.join(exeDir, 'tessdata');
      } else if (Platform.isWindows) {
        return path.join(exeDir, 'tessdata');
      }
    } catch (e) {
      // ignore
    }
    return '';
  }

  TessOcrBindings() {
    _instance = this;
    if (Platform.isLinux) {
      _loadLinux();
    } else if (Platform.isWindows) {
      _loadWindows();
    }
  }

  void _loadLinux() {
    // 优先使用绝对路径：从 bundle/lib/ 加载（匹配 CMAKE_INSTALL_RPATH=$ORIGIN/lib）
    final bundleLib = path.join(
      path.dirname(Platform.resolvedExecutable),
      'lib',
      'libtesseract_ocr.so',
    );
    try {
      _dylib = DynamicLibrary.open(bundleLib);
      _isLinux = true;
      _isLoaded = true;
      _bindLinuxFunctions();
      _getLog().info('OCR', 'Linux FFI loaded: $bundleLib');
      return;
    } catch (e) {
      _getLog().info('OCR', 'Failed to load from bundle path: $e');
    }

    // 回退到名称搜索（适用于开发环境等非 bundle 场景）
    final candidates = [
      'libtesseract_ocr.so',
      'libtesseract_ocr.so.1',
    ];

    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLinux = true;
        _isLoaded = true;
        _bindLinuxFunctions();
        _getLog().info('OCR', 'Linux FFI loaded: $name');
        return;
      } catch (e) {
        _getLog().info('OCR', 'Failed to load $name: $e');
      }
    }
    _isLoaded = false;
  }

  void _bindLinuxFunctions() {
    _linuxCreate = _dylib!.lookupFunction<LinuxTessCreateC, LinuxTessCreateDart>('tess_create');
    _linuxDestroy = _dylib!.lookupFunction<LinuxTessDestroyC, LinuxTessDestroyDart>('tess_destroy');
    _linuxInit = _dylib!.lookupFunction<LinuxTessInitC, LinuxTessInitDart>('tess_init');
    _linuxEnd = _dylib!.lookupFunction<LinuxTessEndC, LinuxTessEndDart>('tess_end');
    _linuxSetImageFile = _dylib!.lookupFunction<LinuxTessSetImageFileC, LinuxTessSetImageFileDart>('tess_set_image_file');
    _linuxGetUtf8Text = _dylib!.lookupFunction<LinuxTessGetUtf8TextC, LinuxTessGetUtf8TextDart>('tess_get_utf8_text');
    _linuxFreeText = _dylib!.lookupFunction<LinuxTessFreeTextC, LinuxTessFreeTextDart>('tess_free_text');
    _linuxVersion = _dylib!.lookupFunction<LinuxTessVersionC, LinuxTessVersionDart>('tess_version');
    _linuxSetVariable = _dylib!.lookupFunction<LinuxTessSetVariableC, LinuxTessSetVariableDart>('tess_set_variable');
  }

  void _loadWindows() {
    final exeDir = path.dirname(Platform.resolvedExecutable);
    final tesseractCandidates = [
      path.join(exeDir, 'tesseract55.dll'),
      path.join(exeDir, 'libtesseract-5.dll'),
      'libtesseract-5.dll',
    ];

    for (final name in tesseractCandidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLinux = false;
        _isLoaded = true;
        _bindWindowsFunctions();
        _getLog().info('OCR', 'Windows Tesseract FFI loaded: $name');

        // 加载 Leptonica
        if (!_loadLeptonica(exeDir)) {
          _getLog().warning('OCR', 'Failed to load Leptonica FFI');
        }
        return;
      } catch (e) {
        _getLog().info('OCR', 'Failed to load $name: $e');
      }
    }
    _isLoaded = false;
  }

  bool _loadLeptonica(String exeDir) {
    final leptonicaCandidates = [
      path.join(exeDir, 'leptonica-1.87.0.dll'),
      path.join(exeDir, 'libleptonica-5.dll'),
    ];

    for (final name in leptonicaCandidates) {
      try {
        _leptonicaLib = DynamicLibrary.open(name);
        _bindLeptonicaFunctions();
        _getLog().info('OCR', 'Windows Leptonica FFI loaded: $name');
        return true;
      } catch (e) {
        _getLog().info('OCR', 'Failed to load Leptonica $name: $e');
      }
    }
    return false;
  }

  void _bindWindowsFunctions() {
    _winCreate = _dylib!.lookupFunction<WinTessBaseAPICreateC, WinTessBaseAPICreateDart>('TessBaseAPICreate');
    _winDelete = _dylib!.lookupFunction<WinTessBaseAPIDeleteC, WinTessBaseAPIDeleteDart>('TessBaseAPIDelete');
    _winInit = _dylib!.lookupFunction<WinTessBaseAPIInit3C, WinTessBaseAPIInit3Dart>('TessBaseAPIInit3');
    _winEnd = _dylib!.lookupFunction<WinTessBaseAPIEndC, WinTessBaseAPIEndDart>('TessBaseAPIEnd');
    _winSetImage2 = _dylib!.lookupFunction<WinTessBaseAPISetImage2C, WinTessBaseAPISetImage2Dart>('TessBaseAPISetImage2');
    _winGetUtf8Text = _dylib!.lookupFunction<WinTessBaseAPIGetUTF8TextC, WinTessBaseAPIGetUTF8TextDart>('TessBaseAPIGetUTF8Text');
    _winDeleteText = _dylib!.lookupFunction<WinTessBaseAPIDeleteTextC, WinTessBaseAPIDeleteTextDart>('TessDeleteText');
    _winVersion = _dylib!.lookupFunction<WinTessVersionC, WinTessVersionDart>('TessVersion');
    _winSetVariable = _dylib!.lookupFunction<WinTessBaseAPISetVariableC, WinTessBaseAPISetVariableDart>('TessBaseAPISetVariable');
  }

  void _bindLeptonicaFunctions() {
    _pixRead = _leptonicaLib!.lookupFunction<PixReadC, PixReadDart>('pixRead');
    _pixDestroy = _leptonicaLib!.lookupFunction<PixDestroyC, PixDestroyDart>('pixDestroy');
  }

  Pointer<Void> create() {
    if (_isLinux) {
      return _linuxCreate!();
    } else {
      return _winCreate!();
    }
  }

  int init(Pointer<Void> handle, String datapath, String language) {
    final datapathPtr = datapath.toNativeUtf8();
    final langPtr = language.toNativeUtf8();
    int result;
    if (_isLinux) {
      result = _linuxInit!(handle, datapathPtr, langPtr);
    } else {
      result = _winInit!(handle, datapathPtr, langPtr);
    }
    malloc.free(datapathPtr);
    malloc.free(langPtr);
    return result;
  }

  int setImageFile(Pointer<Void> handle, String filename) {
    if (_isLinux) {
      final filenamePtr = filename.toNativeUtf8();
      final result = _linuxSetImageFile!(handle, filenamePtr);
      malloc.free(filenamePtr);
      return result;
    } else {
      // Windows: 使用 pixRead 读取图像，再用 TessBaseAPISetImage2 设置
      if (_pixRead == null || _winSetImage2 == null) {
        _getLog().error('OCR', 'Leptonica not loaded, cannot set image');
        return -1;
      }
      final filenamePtr = filename.toNativeUtf8();
      final pix = _pixRead!(filenamePtr);
      malloc.free(filenamePtr);
      if (pix == nullptr) {
        _getLog().error('OCR', 'pixRead failed for: $filename');
        return -1;
      }
      _winSetImage2!(handle, pix);
      // 释放 Pix 内存
      final pixPtr = calloc<Pointer<Void>>();
      pixPtr.value = pix;
      _pixDestroy!(pixPtr);
      calloc.free(pixPtr);
      return 0;
    }
  }

  String? getUtf8Text(Pointer<Void> handle) {
    Pointer<Utf8> resultPtr;
    if (_isLinux) {
      resultPtr = _linuxGetUtf8Text!(handle);
    } else {
      resultPtr = _winGetUtf8Text!(handle);
    }
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    if (_isLinux) {
      _linuxFreeText!(resultPtr);
    } else {
      _winDeleteText!(resultPtr);
    }
    return result;
  }

  void end(Pointer<Void> handle) {
    if (_isLinux) {
      _linuxEnd!(handle);
    } else {
      _winEnd!(handle);
    }
  }

  void destroy(Pointer<Void> handle) {
    if (_isLinux) {
      _linuxDestroy!(handle);
    } else {
      _winDelete!(handle);
    }
  }

  String? getVersion() {
    if (_isLinux) {
      final ptr = _linuxVersion!();
      if (ptr == nullptr) return null;
      final result = ptr.toDartString();
      _linuxFreeText!(ptr);
      return result;
    } else {
      final ptr = _winVersion!();
      if (ptr == nullptr) return null;
      return ptr.toDartString();
    }
  }

  int setVariable(Pointer<Void> handle, String name, String value) {
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    int result;
    if (_isLinux) {
      result = _linuxSetVariable!(handle, namePtr, valuePtr);
    } else {
      result = _winSetVariable!(handle, namePtr, valuePtr);
    }
    malloc.free(namePtr);
    malloc.free(valuePtr);
    return result;
  }
}
