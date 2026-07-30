import 'dart:io';

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
/// - Linux: Tesseract CLI（自动检测发行版，一键安装向导）
/// - Windows: Tesseract FFI
///
/// 支持中文和英文文本识别。使用相机或图片文件进行 OCR。
/// 每次使用后必须调用 [close] 释放资源。
///
/// ## Linux OCR 安装
///
/// Linux 用户首次使用 OCR 时，如未安装 Tesseract，会显示安装向导。
/// 支持 Fedora/Debian/Ubuntu/Arch/openSUSE 等主流发行版。
/// 详细文档见 [showLinuxOcrInstallDialog]。
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

  /// Linux: 检查 Tesseract CLI 是否已安装
  static Future<bool> linuxCheckInstalled() async {
    if (!Platform.isLinux) return false;
    return _LinuxOcrService().isInstalled();
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
    return _WindowsOcrService().isInstalled();
  }

  /// Windows: 后台检测 Tesseract，未安装时打印日志提示
  static void windowsCheckAndNotify() {
    if (!Platform.isWindows) return;
    Future.microtask(() async {
      final installed = await _WindowsOcrService().isInstalled();
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

/// Tesseract OCR 服务基类（Windows 专用）
///
/// 使用 FFI 调用打包的 Tesseract DLL，或回退到命令行 tesseract。
abstract class _TesseractOcrServiceBase {
  static final _log = LogService.instance;

  /// 检查 tesseract 是否已安装 - 由子类实现平台特定逻辑
  Future<bool> isInstalled();

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

      return _recognizeWithCli(imagePath, diag);
    } catch (e) {
      diag.write('识别异常: $e');
      return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
    }
  }

  Future<OcrResult> _recognizeWithCli(String imagePath, StringBuffer diag) async {
    _log.info('OCR', '[CLI] 开始 OCR 识别: $imagePath');
    var result = await _runTesseract(imagePath, 'chi_sim+eng');
    if (result.text.trim().isEmpty) {
      _log.info('OCR', '[CLI] chi_sim+eng 无结果，尝试 eng');
      result = await _runTesseract(imagePath, 'eng');
      diag.write('语言=eng(降级) ');
    } else {
      diag.write('语言=chi_sim+eng ');
    }
    final normalizedText = _normalizeOcrText(result.text);
    diag.write('文字="${_truncateText(normalizedText, 80)}"');

    _log.info('OCR', '[CLI] OCR 完成，最终文字 ${normalizedText.length} 字符');

    return OcrResult(
      text: normalizedText,
      blocks: [],
      diagnostics: [diag.toString()],
    );
  }

  Future<_TesseractResult> _runTesseract(String imagePath, String language) async {
    final cmd = 'tesseract "$imagePath" stdout -l $language --psm 3 --oem 1';
    _log.info('OCR', '[CLI] 执行命令: $cmd');

    final result = await Process.run('tesseract', [
      imagePath,
      'stdout',
      '-l', language,
      '--psm', '3', '--oem', '1',
    ]);

    final stdout = result.stdout.toString().trim();
    final stderr = result.stderr.toString().trim();

    if (result.exitCode == 0) {
      _log.info('OCR', '[CLI] 命令成功，输出 ${stdout.length} 字符');
      if (stdout.length > 100) {
        _log.info('OCR', '[CLI] 输出预览: "${stdout.substring(0, 100)}..."');
      } else if (stdout.isNotEmpty) {
        _log.info('OCR', '[CLI] 输出: "$stdout"');
      }
    } else {
      _log.warning('OCR', '[CLI] 命令失败，exitCode=${result.exitCode}');
      if (stderr.isNotEmpty) {
        _log.warning('OCR', '[CLI] stderr: $stderr');
      }
    }

    return _TesseractResult(
      text: stdout,
      language: language,
      exitCode: result.exitCode,
      stderr: stderr,
    );
  }

  String _truncateText(String text, int maxLen) {
    if (text.isEmpty) return '';
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }

  /// 清理 OCR 文本中的字符间空格
  /// Tesseract 有时会输出 "当 你 有" 这样每个字之间有空格的结果
  String _normalizeOcrText(String text) {
    if (text.isEmpty) return text;
    // 移除中文/日文/韩文字符之间的单个空格
    // 匹配模式:CJK字符 + 空格 + CJK字符
    return text.replaceAll(RegExp(r'([\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af])\s+([\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af])'), r'$1$2');
  }

  void close() {
    _disposed = true;
  }
}

/// Linux Tesseract OCR 实现
///
/// 使用 Tesseract CLI 进行文字识别。
class _LinuxOcrService extends _TesseractOcrServiceBase {
  @override
  String get _installHint => '请运行: sudo dnf install tesseract tesseract-lang';

  /// 检查 tesseract CLI 是否已安装
  @override
  Future<bool> isInstalled() async {
    try {
      _TesseractOcrServiceBase._log.info('OCR', '检查 Tesseract CLI (Linux)...');
      try {
        _TesseractOcrServiceBase._log.info('OCR', '尝试命令行: tesseract');
        final result = await Process.run('tesseract', ['--version']);
        _TesseractOcrServiceBase._log.info('OCR', 'tesseract exitCode=${result.exitCode}');
        if (result.exitCode == 0 && result.stdout.toString().isNotEmpty) {
          _TesseractOcrServiceBase._log.info('OCR', 'tesseract 命令行版本: ${result.stdout.toString().trim()}');
          return true;
        }
      } catch (e) {
        _TesseractOcrServiceBase._log.info('OCR', 'tesseract 不可用: $e');
      }

      _TesseractOcrServiceBase._log.warning('OCR', 'tesseract 未安装或不可用');
      return false;
    } catch (e, st) {
      _TesseractOcrServiceBase._log.error('OCR', '检查 tesseract 失败: $e\n$st');
      return false;
    }
  }
}

/// Windows Tesseract OCR 实现
///
/// 使用 FFI 调用打包的 Tesseract DLL，或回退到命令行 tesseract。
class _WindowsOcrService extends _TesseractOcrServiceBase {
  static TessOcrBindings? _bindings;

  /// 获取 FFI bindings（延迟初始化）
  static TessOcrBindings? get _ffi => _bindings ??= TessOcrBindings();

  @override
  String get _installHint => '请从 https://github.com/UB-Mannheim/tesseract/wiki 下载安装';

  /// 检查 tesseract 是否已安装（FFI）
  /// Windows 只支持 FFI，不支持 CLI
  @override
  Future<bool> isInstalled() async {
    try {
      _TesseractOcrServiceBase._log.info('OCR', '检查 Tesseract FFI (Windows)...');
      if (_ffi?.isLoaded ?? false) {
        final version = _ffi?.getVersion();
        _TesseractOcrServiceBase._log.info('OCR', 'Tesseract FFI 已加载${version != null ? ', 版本: $version' : ''}');
        return true;
      }
      // Windows 只支持 FFI 方式，不支持 CLI
      _TesseractOcrServiceBase._log.warning('OCR', 'Tesseract FFI 未加载 (Windows)');
      return false;
    } catch (e) {
      _TesseractOcrServiceBase._log.error('OCR', '检查 Tesseract FFI 失败 (Windows): $e');
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
