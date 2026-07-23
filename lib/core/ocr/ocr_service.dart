import 'dart:ffi';
import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/log_service.dart';
import 'tesseract_bindings.dart';

/// OCR 识别结果
class OcrResult {
  final String text;
  final List<OcrBlock> blocks;
  /// 诊断信息：各脚本尝试的结果
  final List<String> diagnostics;

  const OcrResult({
    required this.text,
    required this.blocks,
    this.diagnostics = const [],
  });

  bool get isEmpty => text.trim().isEmpty;
}

class OcrBlock {
  final String text;
  final Rect boundingBox;

  const OcrBlock({required this.text, required this.boundingBox});
}

/// OCR 识别服务
///
/// - Android/iOS: Google ML Kit Text Recognition
/// - macOS: Apple Vision Framework (Method Channel)
/// - Linux: Tesseract FFI/CLI
/// - Windows: Tesseract FFI/CLI
///
/// 支持中文和英文文本识别。使用相机或图片文件进行 OCR。
/// 每次使用后必须调用 [close] 释放资源。
class OcrService {
  final _MlKitOcrService? _mlKitService;
  final _LinuxOcrService? _linuxService;
  final _MacOSVisionOcrService? _macVisionService;
  final _WindowsOcrService? _windowsService;

  /// 工厂构造函数，根据平台返回对应实现
  factory OcrService() {
    if (Platform.isAndroid || Platform.isIOS) {
      return OcrService._(mlKitService: _MlKitOcrService());
    } else if (Platform.isLinux) {
      return OcrService._(linuxService: _LinuxOcrService());
    } else if (Platform.isMacOS) {
      return OcrService._(macVisionService: _MacOSVisionOcrService());
    } else if (Platform.isWindows) {
      return OcrService._(windowsService: _WindowsOcrService());
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }
  }

  OcrService._({
    _MlKitOcrService? mlKitService,
    _LinuxOcrService? linuxService,
    _MacOSVisionOcrService? macVisionService,
    _WindowsOcrService? windowsService,
  })  : _mlKitService = mlKitService,
        _linuxService = linuxService,
        _macVisionService = macVisionService,
        _windowsService = windowsService;

  /// 识图图片文件中的文字
  ///
  /// [diagnostics] 不为空时，会填充各脚本的尝试结果（用于 LogViewer 诊断）。
  Future<OcrResult> recognizeImage(String imagePath) async {
    if (_mlKitService != null) {
      return _mlKitService.recognizeImage(imagePath);
    } else if (_linuxService != null) {
      return _linuxService.recognizeImage(imagePath);
    } else if (_macVisionService != null) {
      return _macVisionService.recognizeImage(imagePath);
    } else if (_windowsService != null) {
      return _windowsService.recognizeImage(imagePath);
    }
    throw StateError('无可用的 OCR 服务');
  }

  /// 释放资源
  void close() {
    _mlKitService?.close();
    _linuxService?.close();
    _macVisionService?.close();
    _windowsService?.close();
  }

  /// Linux: 检查 Tesseract 是否已安装
  static Future<bool> linuxCheckInstalled() async {
    if (!Platform.isLinux) return false;
    return _LinuxOcrService.isInstalled();
  }

  /// Linux: 后台检测 Tesseract，未安装时打印日志提示
  /// 注意：UI 提示需要在 Widget tree 构建后通过 context 获取 ScaffoldMessenger
  /// 这里只打印 debug 日志，实际提示由 recognizeImage 的诊断结果提供
  static void linuxCheckAndNotify() {
    if (!Platform.isLinux) return;
    Future.microtask(() async {
      final installed = await _LinuxOcrService.isInstalled();
      if (!installed) {
        debugPrint('[Linux] Tesseract not found. To install run:');
        debugPrint('[Linux]   sudo dnf install tesseract tesseract-lang leptonica');
        debugPrint('[Linux] Or use pkexec for GUI prompt: OcrService.linuxTryInstall()');
      }
    });
  }

  /// Linux: 尝试自动安装 Tesseract OCR 及语言包
  /// 需要用户输入密码（通过 polkit 弹窗）
  /// 返回安装是否成功
  static Future<bool> linuxTryInstall() async {
    if (!Platform.isLinux) return false;
    return _LinuxOcrService.tryInstall();
  }

  /// macOS: 检查 Vision OCR 是否可用（始终可用，系统框架）
  static Future<bool> macOSCheckInstalled() async {
    if (!Platform.isMacOS) return false;
    return true;
  }

  /// macOS: Vision OCR 已集成，无需额外安装
  static void macOSCheckAndNotify() {
    // Apple Vision 是系统框架，始终可用，无需提示安装
  }

  /// Windows: 检查 Tesseract 是否已安装
  static Future<bool> windowsCheckInstalled() async {
    if (!Platform.isWindows) return false;
    return _WindowsOcrService.isInstalled();
  }

  /// Windows: 后台检测 Tesseract，未安装时打印日志提示
  static void windowsCheckAndNotify() {
    if (!Platform.isWindows) return;
    Future.microtask(() async {
      final installed = await _WindowsOcrService.isInstalled();
      if (!installed) {
        debugPrint('[Windows] Tesseract not found. To install download from:');
        debugPrint('[Windows]   https://github.com/UB-Mannheim/tesseract/wiki');
        debugPrint('[Windows]   Install with default options and ensure tesseract is in PATH');
      }
    });
  }
}

/// macOS Tesseract OCR 实现
///
/// 使用 Apple Vision Framework 通过 Method Channel 调用 Swift 代码
class _MacOSVisionOcrService {
  static const _channel = MethodChannel('com.mememaster/vision_ocr');
  static final _log = LogService.instance;

  Future<OcrResult> recognizeImage(String imagePath) async {
    try {
      _log.info('OCR', '[Vision] 开始识别: $imagePath');
      final result = await _channel.invokeMethod<Map>(
        'recognizeText',
        {'imagePath': imagePath},
      );

      if (result == null) {
        _log.warning('OCR', '[Vision] 返回结果为 null');
        return const OcrResult(text: '', blocks: []);
      }

      final text = result['text'] as String? ?? '';
      final blocks = (result['blocks'] as List?)?.map((b) {
        final block = b as Map;
        return OcrBlock(
          text: block['text'] as String,
          boundingBox: Rect.fromLTWH(
            (block['x'] as num).toDouble(),
            (block['y'] as num).toDouble(),
            (block['width'] as num).toDouble(),
            (block['height'] as num).toDouble(),
          ),
        );
      }).toList() ?? [];

      _log.info('OCR', '[Vision] 识别完成: ${text.length} 字符, ${blocks.length} 块');
      return OcrResult(text: text, blocks: blocks);
    } on PlatformException catch (e) {
      _log.error('OCR', '[Vision] 识别失败: ${e.message}');
      return OcrResult(text: '', blocks: [], diagnostics: ['[Vision] ${e.message}']);
    }
  }

  void close() {}
}

/// Google ML Kit OCR 实现（Android/iOS）
class _MlKitOcrService {
  /// 识图图片文件中的文字
  Future<OcrResult> recognizeImage(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult(text: '', blocks: [], diagnostics: ['文件不存在: $imagePath']);
    }

    InputImage inputImage;
    try {
      inputImage = InputImage.fromFile(file);
    } catch (e) {
      return const OcrResult(text: '', blocks: [], diagnostics: ['创建 InputImage 失败']);
    }

    final allDiagnostics = <String>[];

    // 先用 Chinese 脚本识别
    {
      final result = await _tryRecognize(inputImage, TextRecognitionScript.chinese);
      allDiagnostics.addAll(result?.diagnostics ?? []);
      if (result != null && !result.isEmpty) {
        return OcrResult(text: result.text, blocks: result.blocks, diagnostics: allDiagnostics);
      }
    }

    // Chinese 没识别到 → 降级到 Latin 诊断
    {
      final result = await _tryRecognize(inputImage, TextRecognitionScript.latin);
      allDiagnostics.addAll(result?.diagnostics ?? []);
      if (result != null && !result.isEmpty) {
        return OcrResult(text: result.text, blocks: result.blocks, diagnostics: allDiagnostics);
      }
    }

    return OcrResult(text: '', blocks: [], diagnostics: allDiagnostics);
  }

  Future<OcrResult?> _tryRecognize(InputImage inputImage, TextRecognitionScript script) async {
    final recognizer = TextRecognizer(script: script);
    final diag = StringBuffer();
    diag.write('[$script] ');
    try {
      final recognizedText = await recognizer.processImage(inputImage);
      diag.write('块数=${recognizedText.blocks.length}');
      if (recognizedText.text.length > 80) {
        diag.write(', 文字="${recognizedText.text.substring(0, 80)}..."');
      } else if (recognizedText.text.isNotEmpty) {
        diag.write(', 文字="${recognizedText.text}"');
      }

      if (recognizedText.text.isEmpty && recognizedText.blocks.isEmpty) {
        return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
      }

      return OcrResult(
        text: recognizedText.text,
        blocks: recognizedText.blocks.map((block) {
          return OcrBlock(text: block.text, boundingBox: block.boundingBox);
        }).toList(),
        diagnostics: [diag.toString()],
      );
    } catch (e) {
      diag.write('识别异常: $e');
      return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
    } finally {
      recognizer.close();
    }
  }

  void close() {}
}

/// Tesseract OCR 服务基类（Linux/Windows 共用）
///
/// 使用 FFI 调用 libtesseract_ocr.so/libtesseract-5.dll，或回退到命令行 tesseract。
abstract class _TesseractOcrServiceBase {
  static final _log = LogService.instance;
  static TessOcrBindings? _bindings;

  /// 获取 FFI bindings（延迟初始化）
  static TessOcrBindings? get _ffi => _bindings ??= TessOcrBindings();

  /// 检查 tesseract 是否已安装（FFI 或命令行）- 由子类实现平台特定逻辑
  static Future<bool> isInstalled();

  bool _disposed = false;

  /// 获取安装提示消息 - 由子类实现
  String get _installHint;

  /// 识图图片文件中的文字
  Future<OcrResult> recognizeImage(String imagePath) async {
    if (_disposed) throw StateError('服务已释放');

    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult(text: '', blocks: [], diagnostics: ['文件不存在: $imagePath']);
    }

    final diag = StringBuffer();
    diag.write('[Tesseract] ');

    try {
      final installed = await isInstalled();
      if (!installed) {
        return OcrResult(
          text: '',
          blocks: [],
          diagnostics: ['${diag}Tesseract 未安装。$_installHint'],
        );
      }

      if (_ffi?.isLoaded ?? false) {
        return _recognizeWithFfi(imagePath, diag);
      } else {
        return _recognizeWithCli(imagePath, diag);
      }
    } catch (e) {
      diag.write('识别异常: $e');
      return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
    }
  }

  OcrResult _recognizeWithFfi(String imagePath, StringBuffer diag) {
    Pointer<Void>? handle;
    final ffi = _ffi!;
    try {
      handle = ffi.create();
      if (handle == nullptr) {
        _log.error('OCR', '创建 Tesseract handle 失败');
        return OcrResult(text: '', blocks: [], diagnostics: ['${diag}创建 Tesseract handle 失败']);
      }
      _log.info('OCR', '创建 Tesseract handle 成功');

      final datapath = TessOcrBindings.getTessdataPath();
      _log.info('OCR', 'FFI datapath: $datapath');
      _log.info('OCR', '图片路径: $imagePath');

      var result = ffi.init(handle, datapath, 'chi_sim+eng');
      _log.info('OCR', 'Tesseract init 结果: $result (语言=chi_sim+eng)');
      if (result != 0) {
        result = ffi.init(handle, datapath, 'eng');
        _log.info('OCR', 'Tesseract init 结果: $result (语言=eng)');
        if (result != 0) {
          _log.error('OCR', 'Tesseract 初始化失败: $result');
          return OcrResult(text: '', blocks: [], diagnostics: ['${diag}Tesseract 初始化失败 (FFI)']);
        }
        diag.write('语言=eng(降级) ');
      } else {
        diag.write('语言=chi_sim+eng ');
      }

      final setImageResult = ffi.setImageFile(handle, imagePath);
      _log.info('OCR', 'setImageFile 结果: $setImageResult');
      if (setImageResult != 0) {
        _log.error('OCR', '加载图片失败: $imagePath');
        return OcrResult(text: '', blocks: [], diagnostics: ['${diag}加载图片失败: $imagePath']);
      }

      final text = ffi.getUtf8Text(handle);
      _log.info('OCR', 'OCR 识别结果: ${text?.length ?? 0} 字符');
      diag.write('文字="${_truncateText(text ?? '', 80)}"');
      return OcrResult(text: text ?? '', blocks: [], diagnostics: [diag.toString()]);
    } finally {
      if (handle != null && handle != nullptr) {
        ffi.end(handle);
        ffi.destroy(handle);
      }
    }
  }

  Future<OcrResult> _recognizeWithCli(String imagePath, StringBuffer diag) async {
    var result = await _runTesseract(imagePath, 'chi_sim+eng');
    if (result.text.trim().isEmpty) {
      result = await _runTesseract(imagePath, 'eng');
      diag.write('语言=eng(降级) ');
    } else {
      diag.write('语言=chi_sim+eng ');
    }
    diag.write('文字="${_truncateText(result.text, 80)}"');
    return OcrResult(
      text: result.text,
      blocks: [],
      diagnostics: [diag.toString()],
    );
  }

  Future<_TesseractResult> _runTesseract(String imagePath, String language) async {
    final result = await Process.run('tesseract', [
      imagePath,
      'stdout',
      '-l', language,
      '--psm', '6',
    ]);
    return _TesseractResult(
      text: result.stdout.toString().trim(),
      language: language,
      exitCode: result.exitCode,
      stderr: result.stderr.toString(),
    );
  }

  String _truncateText(String text, int maxLen) {
    if (text.isEmpty) return '';
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  void close() {
    _disposed = true;
  }
}

/// Linux Tesseract OCR 实现
///
/// 使用 FFI 调用 libtesseract_ocr.so（内置 Tesseract + Leptonica 共享库）。
/// 回退到命令行 tesseract（如果 FFI 不可用）。
class _LinuxOcrService extends _TesseractOcrServiceBase {
  @override
  String get _installHint => '尝试自动安装: OcrService.linuxTryInstall()';

  /// 检查 tesseract 是否已安装（FFI 或命令行）
  static Future<bool> isInstalled() async {
    try {
      _log.info('OCR', '检查 Tesseract 是否可用...');

      // 检查 FFI 是否可用
      final ffiLoaded = _ffi?.isLoaded ?? false;
      _log.info('OCR', 'Tesseract FFI loaded: $ffiLoaded');

      if (ffiLoaded) {
        final version = _ffi?.getVersion();
        _log.info('OCR', 'Tesseract FFI 已加载${version != null ? ', 版本: $version' : ''}');
        return true;
      }

      // FFI 不可用，尝试命令行
      try {
        _log.info('OCR', '尝试命令行: tesseract');
        final result = await Process.run('tesseract', ['--version']);
        _log.info('OCR', 'tesseract exitCode=${result.exitCode}');
        if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
          _log.info('OCR', 'tesseract 命令行版本: ${result.stdout.toString().trim()}');
          return true;
        }
      } catch (e) {
        _log.info('OCR', 'tesseract 不可用: $e');
      }

      _log.warning('OCR', 'tesseract 未安装或不可用');
      return false;
    } catch (e, st) {
      _log.error('OCR', '检查 tesseract 失败: $e\n$st');
      return false;
    }
  }

  /// 尝试自动安装 tesseract（需要 root 权限）
  /// 返回安装是否成功
  static Future<bool> tryInstall() async {
    try {
      final result = await Process.run('pkexec', [
        'dnf', 'install', '-y', 'tesseract', 'tesseract-lang', 'leptonica'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }
}

/// Windows Tesseract OCR 实现
///
/// 使用 FFI 调用打包的 Tesseract DLL，或回退到命令行 tesseract。
class _WindowsOcrService extends _TesseractOcrServiceBase {
  @override
  String get _installHint => '请从 https://github.com/UB-Mannheim/tesseract/wiki 下载安装';

  /// 检查 tesseract 是否已安装（FFI 或命令行）
  static Future<bool> isInstalled() async {
    try {
      _log.info('OCR', '检查 Tesseract 是否可用 (Windows)...');
      if (_ffi?.isLoaded ?? false) {
        final version = _ffi?.getVersion();
        _log.info('OCR', 'Tesseract FFI 已加载${version != null ? ', 版本: $version' : ''}');
        return true;
      }
      final result = await Process.run('where', ['tesseract']);
      _log.info('OCR', 'where tesseract exitCode=${result.exitCode}');
      if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
        _log.info('OCR', 'tesseract 命令行路径: ${result.stdout.toString().trim()}');
        return true;
      }
      _log.warning('OCR', 'tesseract 未安装或不在 PATH 中 (Windows)');
      return false;
    } catch (e) {
      _log.error('OCR', '检查 tesseract 失败 (Windows): $e');
      return false;
    }
  }
}

class _TesseractResult {
  final String text;
  final String language;
  final int exitCode;
  final String stderr;

  _TesseractResult({
    required this.text,
    required this.language,
    required this.exitCode,
    required this.stderr,
  });
}
