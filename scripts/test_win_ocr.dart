import 'dart:ffi';
import 'dart:io' show Directory, File, exit;
import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as path;

typedef WinTessBaseAPICreateC = Pointer<Void> Function();
typedef WinTessBaseAPICreateDart = Pointer<Void> Function();

typedef WinTessBaseAPIDeleteC = Void Function(Pointer<Void>);
typedef WinTessBaseAPIDeleteDart = void Function(Pointer<Void>);

typedef WinTessBaseAPIInit3C = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef WinTessBaseAPIInit3Dart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef WinTessBaseAPIEndC = Void Function(Pointer<Void>);
typedef WinTessBaseAPIEndDart = void Function(Pointer<Void>);

typedef WinTessBaseAPISetImageFileC = Int32 Function(Pointer<Void>, Pointer<Utf8>);
typedef WinTessBaseAPISetImageFileDart = int Function(Pointer<Void>, Pointer<Utf8>);

typedef WinTessBaseAPIGetUTF8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef WinTessBaseAPIGetUTF8TextDart = Pointer<Utf8> Function(Pointer<Void>);

typedef WinTessBaseAPIDeleteTextC = Void Function(Pointer<Utf8>);
typedef WinTessBaseAPIDeleteTextDart = void Function(Pointer<Utf8>);

typedef WinTessVersionC = Pointer<Utf8> Function();
typedef WinTessVersionDart = Pointer<Utf8> Function();

class WinTessOcrBindings {
  DynamicLibrary? _dylib;

  late WinTessBaseAPICreateDart tessCreate;
  late WinTessBaseAPIDeleteDart tessDelete;
  late WinTessBaseAPIInit3Dart tessInit;
  late WinTessBaseAPIEndDart tessEnd;
  late WinTessBaseAPISetImageFileDart tessSetImageFile;
  late WinTessBaseAPIGetUTF8TextDart tessGetUtf8Text;
  late WinTessBaseAPIDeleteTextDart tessDeleteText;
  late WinTessVersionDart tessVersion;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  WinTessOcrBindings(String dllDir) {
    final candidates = [
      path.join(dllDir, 'tesseract55.dll'),
      path.join(dllDir, 'libtesseract-5.dll'),
      path.join(dllDir, 'tesseract55.dll'),
    ];

    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLoaded = true;
        _bindFunctions();
        print('WinTessOcrBindings: loaded $name');
        return;
      } catch (e) {
        _dylib = null;
        _isLoaded = false;
      }
    }
    print('WinTessOcrBindings: failed to load any candidate DLL');
  }

  void _bindFunctions() {
    if (_dylib == null) return;

    tessCreate = _dylib!.lookupFunction<WinTessBaseAPICreateC, WinTessBaseAPICreateDart>('TessBaseAPICreate');
    tessDelete = _dylib!.lookupFunction<WinTessBaseAPIDeleteC, WinTessBaseAPIDeleteDart>('TessBaseAPIDelete');
    tessInit = _dylib!.lookupFunction<WinTessBaseAPIInit3C, WinTessBaseAPIInit3Dart>('TessBaseAPIInit3');
    tessEnd = _dylib!.lookupFunction<WinTessBaseAPIEndC, WinTessBaseAPIEndDart>('TessBaseAPIEnd');
    tessSetImageFile = _dylib!.lookupFunction<WinTessBaseAPISetImageFileC, WinTessBaseAPISetImageFileDart>('TessBaseAPISetImageFile');
    tessGetUtf8Text = _dylib!.lookupFunction<WinTessBaseAPIGetUTF8TextC, WinTessBaseAPIGetUTF8TextDart>('TessBaseAPIGetUTF8Text');
    tessDeleteText = _dylib!.lookupFunction<WinTessBaseAPIDeleteTextC, WinTessBaseAPIDeleteTextDart>('TessBaseAPIDeleteText');
    tessVersion = _dylib!.lookupFunction<WinTessVersionC, WinTessVersionDart>('TessVersion');
  }

  Pointer<Void> create() => tessCreate();

  void destroy(Pointer<Void> handle) => tessDelete(handle);

  int init(Pointer<Void> handle, String datapath, String language) {
    final datapathPtr = datapath.toNativeUtf8();
    final langPtr = language.toNativeUtf8();
    final result = tessInit(handle, datapathPtr, langPtr);
    malloc.free(datapathPtr);
    malloc.free(langPtr);
    return result;
  }

  void end(Pointer<Void> handle) => tessEnd(handle);

  int setImageFile(Pointer<Void> handle, String filename) {
    final filenamePtr = filename.toNativeUtf8();
    final result = tessSetImageFile(handle, filenamePtr);
    malloc.free(filenamePtr);
    return result;
  }

  String? getUtf8Text(Pointer<Void> handle) {
    final resultPtr = tessGetUtf8Text(handle);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    tessDeleteText(resultPtr);
    return result;
  }

  String? getVersion() {
    final resultPtr = tessVersion();
    if (resultPtr == nullptr) return null;
    return resultPtr.toDartString();
  }
}

void main(List<String> args) async {
  if (args.length < 2) {
    print('Usage: dart run test_win_ocr.dart <bundle_dir> <test_image> [expected_text]');
    exit(1);
  }

  final bundleDir = args[0];
  final testImage = args[1];
  final expectedText = args.length > 2 ? args[2] : '';

  print('=== Windows OCR FFI 功能测试 ===');
  print('Bundle 目录: $bundleDir');
  print('测试图片: $testImage');

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

  print('');
  print('=== 加载 FFI 库 ===');
  final bindings = WinTessOcrBindings(dllDir);

  if (!bindings.isLoaded) {
    print('✗ 无法加载 tesseract DLL');
    exit(1);
  }

  print('✓ FFI 库加载成功');
  final version = bindings.getVersion();
  print('Tesseract 版本: ${version ?? "unknown"}');

  Pointer<Void>? handle;
  try {
    print('');
    print('=== OCR 识别测试 ===');

    handle = bindings.create();
    if (handle == nullptr) {
      print('✗ 创建 Tesseract handle 失败');
      exit(1);
    }
    print('✓ Tesseract handle 创建成功');

    print('初始化 Tesseract (chi_sim+eng)...');
    var initResult = bindings.init(handle, tessdataPath, 'chi_sim+eng');

    if (initResult != 0) {
      print('chi_sim+eng 初始化失败，尝试 eng...');
      initResult = bindings.init(handle, tessdataPath, 'eng');
      if (initResult != 0) {
        print('✗ Tesseract 初始化失败: $initResult');
        exit(1);
      }
      print('✓ Tesseract 初始化成功 (eng)');
    } else {
      print('✓ Tesseract 初始化成功 (chi_sim+eng)');
    }

    print('设置图片: $testImage');
    final setImageResult = bindings.setImageFile(handle, testImage);
    if (setImageResult != 0) {
      print('✗ 设置图片失败: $setImageResult');
      exit(1);
    }
    print('✓ 图片设置成功');

    final text = bindings.getUtf8Text(handle);
    if (text == null || text.isEmpty) {
      print('✗ OCR 识别结果为空');
      exit(1);
    }

    print('✓ OCR 识别成功');
    print('识别结果 (前200字符): ${text.length > 200 ? '${text.substring(0, 200)}...' : text}');

    if (expectedText.isNotEmpty) {
      if (text.contains(expectedText)) {
        print('✓ 识别结果包含期望文本: $expectedText');
      } else {
        print('⚠ 识别结果不包含期望文本: $expectedText');
        print('  实际结果: $text');
      }
    }

    print('');
    print('=== 测试完成: 成功 ===');
    exit(0);

  } catch (e) {
    print('✗ 测试异常: $e');
    exit(1);

  } finally {
    if (handle != null && handle != nullptr) {
      bindings.end(handle);
      bindings.destroy(handle);
    }
  }
}
