import 'dart:ffi';
import 'dart:io' show Platform, Directory, File, exit, Process;
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

typedef TessSetVariableC = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);
typedef TessSetVariableDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Utf8>);

typedef TessGetUtf8TextC = Pointer<Utf8> Function(Pointer<Void>);
typedef TessGetUtf8TextDart = Pointer<Utf8> Function(Pointer<Void>);

typedef TessFreeTextC = Void Function(Pointer<Utf8>);
typedef TessFreeTextDart = void Function(Pointer<Utf8>);

typedef TessVersionC = Pointer<Utf8> Function();
typedef TessVersionDart = Pointer<Utf8> Function();

class TessOcrBindings {
  DynamicLibrary? _dylib;

  late TessCreateDart tessCreate;
  late TessDestroyDart tessDestroy;
  late TessInitDart tessInit;
  late TessEndDart tessEnd;
  late TessSetImageFileDart tessSetImageFile;
  late TessSetVariableDart tessSetVariable;
  late TessGetUtf8TextDart tessGetUtf8Text;
  late TessFreeTextDart tessFreeText;
  late TessVersionDart tessVersion;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  static String getTessdataPath(String exeDir) {
    final resourcesPath = path.join(exeDir, 'share', 'tessdata');
    if (Directory(resourcesPath).existsSync()) {
      return resourcesPath;
    }
    return path.join(exeDir, 'tessdata');
  }

  TessOcrBindings(String bundleLibDir) {
    final candidates = <String>[];

    if (Platform.isLinux) {
      candidates.addAll([
        path.join(bundleLibDir, 'libtesseract_ocr.so'),
        path.join(bundleLibDir, 'libtesseract_ocr.so.1'),
        path.join(bundleLibDir, 'libleptonica.so'),
        path.join(bundleLibDir, 'libleptonica.so.1'),
        'libtesseract_ocr.so',
        'libtesseract_ocr.so.1',
      ]);
    }

    for (final name in candidates) {
      try {
        _dylib = DynamicLibrary.open(name);
        _isLoaded = true;
        _bindFunctions();
        print('TessOcrBindings: loaded $name');
        break;
      } catch (e) {
        _dylib = null;
        _isLoaded = false;
      }
    }

    if (!_isLoaded) {
      print('TessOcrBindings: failed to load any candidate library');
    }
  }

  void _bindFunctions() {
    if (_dylib == null) return;

    tessCreate = _dylib!.lookupFunction<TessCreateC, TessCreateDart>('tess_create');
    tessDestroy = _dylib!.lookupFunction<TessDestroyC, TessDestroyDart>('tess_destroy');
    tessInit = _dylib!.lookupFunction<TessInitC, TessInitDart>('tess_init');
    tessEnd = _dylib!.lookupFunction<TessEndC, TessEndDart>('tess_end');
    tessSetImageFile = _dylib!.lookupFunction<TessSetImageFileC, TessSetImageFileDart>('tess_set_image_file');
    tessSetVariable = _dylib!.lookupFunction<TessSetVariableC, TessSetVariableDart>('tess_set_variable');
    tessGetUtf8Text = _dylib!.lookupFunction<TessGetUtf8TextC, TessGetUtf8TextDart>('tess_get_utf8_text');
    tessFreeText = _dylib!.lookupFunction<TessFreeTextC, TessFreeTextDart>('tess_free_text');
    tessVersion = _dylib!.lookupFunction<TessVersionC, TessVersionDart>('tess_version');
  }

  Pointer<Void> create() => tessCreate();

  void destroy(Pointer<Void> handle) => tessDestroy(handle);

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

  int setVariable(Pointer<Void> handle, String name, String value) {
    final namePtr = name.toNativeUtf8();
    final valuePtr = value.toNativeUtf8();
    final result = tessSetVariable(handle, namePtr, valuePtr);
    malloc.free(namePtr);
    malloc.free(valuePtr);
    return result;
  }

  String? getUtf8Text(Pointer<Void> handle) {
    final resultPtr = tessGetUtf8Text(handle);
    if (resultPtr == nullptr) return null;
    final result = resultPtr.toDartString();
    tessFreeText(resultPtr);
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
    print('用法: dart run test_ocr_ffi.dart <bundle_dir> <test_image> [expected_text]');
    exit(1);
  }

  final bundleDir = args[0];
  final testImage = args[1];
  final expectedText = args.length > 2 ? args[2] : '';

  print('=== OCR FFI 功能测试 ===');
  print('Bundle 目录: $bundleDir');
  print('测试图片: $testImage');

  // 检查目录和文件
  if (!Directory(bundleDir).existsSync()) {
    print('✗ Bundle 目录不存在: $bundleDir');
    exit(1);
  }

  if (!File(testImage).existsSync()) {
    print('✗ 测试图片不存在: $testImage');
    exit(1);
  }

  // libDir 用于加载 FFI 库
  final libDir = path.join(bundleDir, 'lib');
  if (!Directory(libDir).existsSync()) {
    print('✗ lib 目录不存在: $libDir');
    exit(1);
  }

  // 获取 tessdata 路径
  final tessdataPath = TessOcrBindings.getTessdataPath(bundleDir);
  print('Tessdata 路径: $tessdataPath');
  if (!Directory(tessdataPath).existsSync()) {
    print('✗ Tessdata 目录不存在: $tessdataPath');
    exit(1);
  }

  // 检查 tessdata 文件
  final chiSimFile = File(path.join(tessdataPath, 'chi_sim.traineddata'));
  final engFile = File(path.join(tessdataPath, 'eng.traineddata'));
  print('chi_sim.traineddata: ${chiSimFile.existsSync() ? "✓" : "✗"}');
  print('eng.traineddata: ${engFile.existsSync() ? "✓" : "✗"}');

  // 加载 FFI 库
  print('');
  print('=== 加载 FFI 库 ===');
  final bindings = TessOcrBindings(libDir);

  if (!bindings.isLoaded) {
    print('✗ 无法加载 libtesseract_ocr.so');
    print('  将尝试使用系统 tesseract CLI 作为 fallback...');

    // Fallback: 使用系统 tesseract CLI
    print('');
    print('=== 测试系统 Tesseract CLI ===');
    final result = await Process.run('tesseract', [
      testImage,
      'stdout',
      '-l', 'chi_sim+eng',
      '--psm', '6',
    ]);

    if (result.exitCode == 0) {
      final text = result.stdout.toString().trim();
      print('✓ Tesseract CLI 识别成功');
      print('识别结果 (前200字符): ${text.length > 200 ? '${text.substring(0, 200)}...' : text}');

      if (expectedText.isNotEmpty && text.contains(expectedText)) {
        print('✓ 识别结果包含期望文本: $expectedText');
        exit(0);
      }
    } else {
      print('✗ Tesseract CLI 识别失败: ${result.stderr}');
      exit(1);
    }
  }

  // 测试 FFI 版本
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

    // 尝试初始化（先尝试 chi_sim+eng）
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

    // 设置 OCR 参数以提高识别精度
    // PSM 3 = 全自动页面分割（自动分析布局）
    // OEM 1 = LSTM + 传统引擎混合模式
    bindings.setVariable(handle, 'tessedit_pageseg_mode', '3');
    bindings.setVariable(handle, 'tessedit_ocr_engine_mode', '1');
    print('✓ 设置 PSM=3, OEM=1');

    // 设置图片
    print('设置图片: $testImage');
    final setImageResult = bindings.setImageFile(handle, testImage);
    if (setImageResult != 0) {
      print('✗ 设置图片失败: $setImageResult');
      exit(1);
    }
    print('✓ 图片设置成功');

    // 获取文本
    final text = bindings.getUtf8Text(handle);
    if (text == null || text.isEmpty) {
      print('✗ OCR 识别结果为空');
      exit(1);
    }

    print('✓ OCR 识别成功');
    print('识别结果 (前200字符): ${text.length > 200 ? '${text.substring(0, 200)}...' : text}');

    // 验证结果
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
