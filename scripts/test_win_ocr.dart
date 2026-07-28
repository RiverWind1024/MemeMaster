import 'dart:ffi';
import 'dart:io' show Directory, File, exit, Platform;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

// ============================================================================
// Tesseract C API typedefs (from capi.h)
// ============================================================================
typedef TessBaseAPICreateC = Pointer<Void> Function();
typedef TessBaseAPICreateDart = Pointer<Void> Function();

typedef TessBaseAPIDeleteC = Void Function(Pointer<Void>);
typedef TessBaseAPIDeleteDart = void Function(Pointer<Void>);

typedef TessBaseAPIInit3C = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef TessBaseAPIInit3Dart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef TessBaseAPIEndC = Void Function(Pointer<Void>);
typedef TessBaseAPIEndDart = void Function(Pointer<Void>);

// TessBaseAPISetImage2 - 设置 Pix 结构体图像
typedef TessBaseAPISetImage2C = Void Function(Pointer<Void>, Pointer<Void>);
typedef TessBaseAPISetImage2Dart = void Function(Pointer<Void>, Pointer<Void>);

typedef TessBaseAPIGetUTF8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef TessBaseAPIGetUTF8TextDart = Pointer<Utf8> Function(Pointer<Void>);

typedef TessBaseAPIDeleteTextC = Void Function(Pointer<Utf8>);
typedef TessBaseAPIDeleteTextDart = void Function(Pointer<Utf8>);

typedef TessVersionC = Pointer<Utf8> Function();
typedef TessVersionDart = Pointer<Utf8> Function();

typedef TessBaseAPISetVariableC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef TessBaseAPISetVariableDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

// ============================================================================
// Leptonica API typedefs (for pixRead)
// ============================================================================
// Pix* pixRead(const char *filename);
typedef PixReadC = Pointer<Void> Function(Pointer<Utf8>);
typedef PixReadDart = Pointer<Void> Function(Pointer<Utf8>);

// void pixDestroy(Pix** pix);
typedef PixDestroyC = Void Function(Pointer<Pointer<Void>>);
typedef PixDestroyDart = void Function(Pointer<Pointer<Void>>);

// ============================================================================
// Windows DLL 搜索路径 API
// ============================================================================
typedef SetDllDirectoryC = Int32 Function(Pointer<Utf16>);
typedef SetDllDirectoryDart = int Function(Pointer<Utf16>);

// ============================================================================
// Windows OCR Bindings
// ============================================================================
class WinTessOcrBindings {
  DynamicLibrary? _tesseractLib;
  DynamicLibrary? _leptonicaLib;

  TessBaseAPICreateDart? tessCreate;
  TessBaseAPIDeleteDart? tessDelete;
  TessBaseAPIInit3Dart? tessInit;
  TessBaseAPIEndDart? tessEnd;
  TessBaseAPISetImage2Dart? tessSetImage2;
  TessBaseAPIGetUTF8TextDart? tessGetUtf8Text;
  TessBaseAPIDeleteTextDart? tessDeleteText;
  TessVersionDart? tessVersion;
  TessBaseAPISetVariableDart? tessSetVariable;

  // Leptonica
  PixReadDart? pixRead;
  PixDestroyDart? pixDestroy;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  WinTessOcrBindings(String dllDir) {
    // Windows: 设置 DLL 搜索路径
    if (Platform.isWindows) {
      _setDllSearchPath(dllDir);
    }

    // 1. 加载 tesseract DLL
    if (!_loadTesseractDll(dllDir)) {
      return;
    }

    // 2. 加载 leptonica DLL
    if (!_loadLeptonicaDll(dllDir)) {
      print('WinTessOcrBindings: failed to load leptonica DLL');
      return;
    }

    _isLoaded = true;
  }

  bool _loadTesseractDll(String dllDir) {
    final candidates = [
      path.join(dllDir, 'tesseract55.dll'),
      path.join(dllDir, 'libtesseract-5.dll'),
    ];

    for (final dllPath in candidates) {
      try {
        _tesseractLib = DynamicLibrary.open(dllPath);
        print('WinTessOcrBindings: loaded tesseract from $dllPath');

        // 绑定 Tesseract 函数
        tessCreate = _tesseractLib!
            .lookupFunction<TessBaseAPICreateC, TessBaseAPICreateDart>('TessBaseAPICreate');
        tessDelete = _tesseractLib!
            .lookupFunction<TessBaseAPIDeleteC, TessBaseAPIDeleteDart>('TessBaseAPIDelete');
        tessInit = _tesseractLib!
            .lookupFunction<TessBaseAPIInit3C, TessBaseAPIInit3Dart>('TessBaseAPIInit3');
        tessEnd = _tesseractLib!
            .lookupFunction<TessBaseAPIEndC, TessBaseAPIEndDart>('TessBaseAPIEnd');
        tessSetImage2 = _tesseractLib!
            .lookupFunction<TessBaseAPISetImage2C, TessBaseAPISetImage2Dart>('TessBaseAPISetImage2');
        tessGetUtf8Text = _tesseractLib!
            .lookupFunction<TessBaseAPIGetUTF8TextC, TessBaseAPIGetUTF8TextDart>('TessBaseAPIGetUTF8Text');
        tessDeleteText = _tesseractLib!
            .lookupFunction<TessBaseAPIDeleteTextC, TessBaseAPIDeleteTextDart>('TessDeleteText');
        tessVersion = _tesseractLib!
            .lookupFunction<TessVersionC, TessVersionDart>('TessVersion');
        tessSetVariable = _tesseractLib!
            .lookupFunction<TessBaseAPISetVariableC, TessBaseAPISetVariableDart>('TessBaseAPISetVariable');

        print('WinTessOcrBindings: all tesseract functions bound');
        return true;
      } catch (e) {
        print('  Failed to load tesseract from $dllPath: $e');
      }
    }
    print('WinTessOcrBindings: failed to load tesseract DLL');
    return false;
  }

  bool _loadLeptonicaDll(String dllDir) {
    final candidates = [
      path.join(dllDir, 'leptonica-1.87.0.dll'),
      path.join(dllDir, 'libleptonica-5.dll'),
    ];

    for (final dllPath in candidates) {
      try {
        _leptonicaLib = DynamicLibrary.open(dllPath);
        print('WinTessOcrBindings: loaded leptonica from $dllPath');

        pixRead = _leptonicaLib!
            .lookupFunction<PixReadC, PixReadDart>('pixRead');
        pixDestroy = _leptonicaLib!
            .lookupFunction<PixDestroyC, PixDestroyDart>('pixDestroy');

        print('WinTessOcrBindings: leptonica functions bound');
        return true;
      } catch (e) {
        print('  Failed to load leptonica from $dllPath: $e');
      }
    }
    print('WinTessOcrBindings: failed to load leptonica DLL');
    return false;
  }

  void _setDllSearchPath(String dllDir) {
    try {
      final kernel32 = DynamicLibrary.open('kernel32.dll');
      final setDllDirectory =
          kernel32.lookupFunction<SetDllDirectoryC, SetDllDirectoryDart>('SetDllDirectoryW');
      final dirPtr = dllDir.toNativeUtf16();
      final result = setDllDirectory(dirPtr);
      malloc.free(dirPtr);
      if (result != 0) {
        print('SetDllDirectory: succeeded for $dllDir');
      } else {
        print('SetDllDirectory: failed for $dllDir');
      }
    } catch (e) {
      print('SetDllDirectory: $e');
    }
  }

  String? getVersion() {
    if (!_isLoaded || tessVersion == null) return null;
    final resultPtr = tessVersion!();
    if (resultPtr == nullptr) return null;
    return resultPtr.toDartString();
  }

  Pointer<Void>? create() => tessCreate?.call();

  void destroy(Pointer<Void> handle) => tessDelete?.call(handle);

  int init(Pointer<Void> handle, String datapath, String language) {
    if (tessInit == null) return -1;
    final datapathPtr = datapath.toNativeUtf8();
    final langPtr = language.toNativeUtf8();
    final result = tessInit!(handle, datapathPtr, langPtr);
    malloc.free(datapathPtr);
    malloc.free(langPtr);
    return result;
  }

  void end(Pointer<Void> handle) => tessEnd?.call(handle);

  /// 使用 pixRead 读取图像并设置
  int setImage(Pointer<Void> handle, String imagePath) {
    if (pixRead == null || tessSetImage2 == null) return -1;

    final imagePathPtr = imagePath.toNativeUtf8();
    final pix = pixRead!(imagePathPtr);
    malloc.free(imagePathPtr);

    if (pix == nullptr) {
      print('WinTessOcrBindings: pixRead failed for $imagePath');
      return -1;
    }

    tessSetImage2!(handle, pix);

    // 释放 Pix 内存
    final pixPtr = calloc<Pointer<Void>>();
    pixPtr.value = pix;
    pixDestroy!(pixPtr);
    calloc.free(pixPtr);

    return 0;
  }

  int setVariable(Pointer<Void> handle, String name, String value) {
    if (tessSetVariable == null) return 0;
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    final result = tessSetVariable!(handle, namePtr, valuePtr);
    malloc.free(namePtr);
    malloc.free(valuePtr);
    return result;
  }

  String? getUtf8Text(Pointer<Void> handle) {
    if (tessGetUtf8Text == null || tessDeleteText == null) return null;
    final resultPtr = tessGetUtf8Text!(handle);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    tessDeleteText!(resultPtr);
    return result;
  }
}

// ============================================================================
// 主测试程序
// ============================================================================
void main(List<String> args) {
  if (args.length < 2) {
    print('用法: dart run test_win_ocr.dart <bundle_dir> <test_image> [expected_text]');
    exit(1);
  }

  final bundleDir = args[0];
  final testImage = args[1];
  final expectedText = args.length > 2 ? args[2] : '';

  print('=== Windows OCR FFI 功能测试 ===');
  print('当前目录: ${Directory.current.path}');
  print('Bundle 目录: $bundleDir');
  print('测试图片: $testImage');
  print('PATH 中的目录: ${Platform.environment['PATH']}');

  if (!Directory(bundleDir).existsSync()) {
    print('✗ Bundle 目录不存在: $bundleDir');
    exit(1);
  }

  if (!File(testImage).existsSync()) {
    print('✗ 测试图片不存在: $testImage');
    exit(1);
  }

  final dllDir = path.join(bundleDir, '');
  final tessdataPath = path.join(bundleDir, 'tessdata');
  print('Tessdata 路径: $tessdataPath');

  if (!Directory(tessdataPath).existsSync()) {
    print('✗ Tessdata 目录不存在: $tessdataPath');
    exit(1);
  }

  final chiSimFile = File(path.join(tessdataPath, 'chi_sim.traineddata'));
  final engFile = File(path.join(tessdataPath, 'eng.traineddata'));
  print('chi_sim.traineddata: ${chiSimFile.existsSync() ? "✓" : "✗"}');
  print('eng.traineddata: ${engFile.existsSync() ? "✓" : "✗"}');

  // 列出所有 DLL
  print('\n=== DLL 文件 ===');
  final dlls = Directory(dllDir).listSync().where((f) => f.path.endsWith('.dll')).toList();
  for (final dll in dlls) {
    print('  ${path.basename(dll.path)}');
  }

  // 加载 FFI 库
  print('\n=== 加载 FFI 库 ===');
  final bindings = WinTessOcrBindings(dllDir);

  if (!bindings.isLoaded) {
    print('✗ FFI 库加载失败');
    exit(1);
  }

  print('✓ FFI 库加载成功');
  print('Tesseract 版本: ${bindings.getVersion()}');

  // 创建 OCR 实例
  print('\n=== OCR 识别 ===');
  final handle = bindings.create();
  if (handle == nullptr) {
    print('✗ 无法创建 OCR 实例');
    exit(1);
  }

  // 初始化
  final initResult = bindings.init(handle, tessdataPath, 'eng+chi_sim');
  if (initResult != 0) {
    print('✗ OCR 初始化失败: $initResult');
    bindings.destroy(handle);
    exit(1);
  }
  print('✓ OCR 初始化成功');

  // 设置 PSM=3 (自动分页)
  bindings.setVariable(handle, 'tessedit_pageseg_mode', '3');
  // 设置 OEM=1 (神经网络 LSTM)
  bindings.setVariable(handle, 'tessedit_ocr_engine_mode', '1');

  // 读取图像并识别
  final setImageResult = bindings.setImage(handle, testImage);
  if (setImageResult != 0) {
    print('✗ 无法设置图像');
    bindings.end(handle);
    bindings.destroy(handle);
    exit(1);
  }
  print('✓ 图像设置成功');

  // 获取识别结果
  final text = bindings.getUtf8Text(handle);
  if (text == null) {
    print('✗ OCR 识别失败');
    bindings.end(handle);
    bindings.destroy(handle);
    exit(1);
  }

  print('\n=== 识别结果 ===');
  print(text.trim());

  // 验证结果（如果提供了期望文本）
  if (expectedText.isNotEmpty) {
    if (text.contains(expectedText)) {
      print('\n✓ 验证通过: 包含期望文本 "$expectedText"');
    } else {
      print('\n✗ 验证失败: 未找到 "$expectedText"');
    }
  }

  // 清理
  bindings.end(handle);
  bindings.destroy(handle);

  print('\n=== 测试完成 ===');
}
