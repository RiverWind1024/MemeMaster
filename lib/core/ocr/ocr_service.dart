import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../services/log_service.dart';

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
/// - Linux/macOS/Windows: Tesseract 命令行
///
/// 支持中文和英文文本识别。使用相机或图片文件进行 OCR。
/// 每次使用后必须调用 [close] 释放资源。
class OcrService {
  final _MlKitOcrService? _mlKitService;
  final _LinuxOcrService? _linuxService;
  final _MacOSOcrService? _macOSService;
  final _WindowsOcrService? _windowsService;

  /// 工厂构造函数，根据平台返回对应实现
  factory OcrService() {
    if (Platform.isAndroid || Platform.isIOS) {
      return OcrService._(mlKitService: _MlKitOcrService());
    } else if (Platform.isLinux) {
      return OcrService._(linuxService: _LinuxOcrService());
    } else if (Platform.isMacOS) {
      return OcrService._(macOSService: _MacOSOcrService());
    } else if (Platform.isWindows) {
      return OcrService._(windowsService: _WindowsOcrService());
    } else {
      throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
    }
  }

  OcrService._({
    _MlKitOcrService? mlKitService,
    _LinuxOcrService? linuxService,
    _MacOSOcrService? macOSService,
    _WindowsOcrService? windowsService,
  })  : _mlKitService = mlKitService,
        _linuxService = linuxService,
        _macOSService = macOSService,
        _windowsService = windowsService;

  /// 识图图片文件中的文字
  ///
  /// [diagnostics] 不为空时，会填充各脚本的尝试结果（用于 LogViewer 诊断）。
  Future<OcrResult> recognizeImage(String imagePath) async {
    if (_mlKitService != null) {
      return _mlKitService.recognizeImage(imagePath);
    } else if (_linuxService != null) {
      return _linuxService.recognizeImage(imagePath);
    } else if (_macOSService != null) {
      return _macOSService.recognizeImage(imagePath);
    } else if (_windowsService != null) {
      return _windowsService.recognizeImage(imagePath);
    }
    throw StateError('无可用的 OCR 服务');
  }

  /// 释放资源
  void close() {
    _mlKitService?.close();
    _linuxService?.close();
    _macOSService?.close();
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

  /// macOS: 检查 Tesseract 是否已安装
  static Future<bool> macOSCheckInstalled() async {
    if (!Platform.isMacOS) return false;
    return _LinuxOcrService.isInstalled();
  }

  /// macOS: 后台检测 Tesseract，未安装时打印日志提示
  static void macOSCheckAndNotify() {
    if (!Platform.isMacOS) return;
    Future.microtask(() async {
      final installed = await _LinuxOcrService.isInstalled();
      if (!installed) {
        debugPrint('[macOS] Tesseract not found. To install run:');
        debugPrint('[macOS]   brew install tesseract tesseract-lang');
      }
    });
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
/// 与 Linux 共用相同的 Tesseract 命令行实现
typedef _MacOSOcrService = _LinuxOcrService;

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

/// Linux Tesseract OCR 实现
///
/// 通过调用系统 tesseract 命令进行 OCR 识别。
/// 需要系统安装 tesseract 和对应语言包。
class _LinuxOcrService {
  bool _disposed = false;
  static final _log = LogService();

  /// 检查 tesseract 是否已安装
  static Future<bool> isInstalled() async {
    try {
      _log.info('OCR', '检查 tesseract 是否已安装...');
      final result = await Process.run('tesseract', ['--version']);
      _log.info('OCR', 'tesseract --version exitCode=${result.exitCode}');
      if (result.exitCode != 0) {
        _log.warning('OCR', 'tesseract --version stderr: ${result.stderr}');
      }
      if (result.stdout.toString().isNotEmpty) {
        _log.info('OCR', 'tesseract version: ${result.stdout.toString().trim()}');
      }
      return result.exitCode == 0;
    } catch (e) {
      _log.error('OCR', '检查 tesseract 失败: $e');
      return false;
    }
  }

  /// 尝试自动安装 tesseract（需要 root 权限）
  /// 返回安装是否成功
  static Future<bool> tryInstall() async {
    try {
      // 尝试使用 pkexec 调用 dnf 安装（会弹窗请求密码）
      final result = await Process.run('pkexec', [
        'dnf', 'install', '-y', 'tesseract', 'tesseract-lang', 'leptonica'
      ]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<OcrResult> recognizeImage(String imagePath) async {
    if (_disposed) throw StateError('服务已释放');

    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult(text: '', blocks: [], diagnostics: ['文件不存在: $imagePath']);
    }

    final diag = StringBuffer();
    diag.write('[Tesseract] ');

    try {
      // 检查 tesseract 是否可用
      final installed = await isInstalled();
      if (!installed) {
        return OcrResult(
          text: '',
          blocks: [],
          diagnostics: ['${diag}Tesseract 未安装。尝试自动安装: OcrService.linuxTryInstall()'],
        );
      }

      // 先尝试中文+英文
      var result = await _runTesseract(imagePath, 'chi_sim+eng');
      if (result.text.trim().isEmpty) {
        // 降级到纯英文
        result = await _runTesseract(imagePath, 'eng');
      }

      diag.write('语言=${result.language}, 文字="${_truncateText(result.text, 80)}"');
      return OcrResult(
        text: result.text,
        blocks: [], // Tesseract 命令行不返回位置信息
        diagnostics: [diag.toString()],
      );
    } catch (e) {
      diag.write('识别异常: $e');
      return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
    }
  }

  Future<_TesseractResult> _runTesseract(String imagePath, String language) async {
    final result = await Process.run('tesseract', [
      imagePath,
      'stdout',
      '-l', language,
      '--psm', '6', // 自动分页
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

/// Windows Tesseract OCR 实现
///
/// 通过调用系统 tesseract 命令进行 OCR 识别。
/// Windows 上使用 `where tesseract` 检测安装。
class _WindowsOcrService {
  bool _disposed = false;
  static final _log = LogService();

  /// 检查 tesseract 是否已安装（使用 where 命令）
  static Future<bool> isInstalled() async {
    try {
      _log.info('OCR', '检查 tesseract 是否已安装 (Windows)...');
      final result = await Process.run('where', ['tesseract']);
      _log.info('OCR', 'where tesseract exitCode=${result.exitCode}');
      if (result.exitCode != 0) {
        _log.warning('OCR', 'where tesseract stderr: ${result.stderr}');
      }
      if (result.stdout.toString().isNotEmpty) {
        _log.info('OCR', 'tesseract path: ${result.stdout.toString().trim()}');
      }
      return result.exitCode == 0;
    } catch (e) {
      _log.error('OCR', '检查 tesseract 失败 (Windows): $e');
      return false;
    }
  }

  Future<OcrResult> recognizeImage(String imagePath) async {
    if (_disposed) throw StateError('服务已释放');

    final file = File(imagePath);
    if (!await file.exists()) {
      return OcrResult(text: '', blocks: [], diagnostics: ['文件不存在: $imagePath']);
    }

    final diag = StringBuffer();
    diag.write('[Tesseract] ');

    try {
      // 检查 tesseract 是否可用
      final installed = await isInstalled();
      if (!installed) {
        return OcrResult(
          text: '',
          blocks: [],
          diagnostics: ['${diag}Tesseract 未安装。请从 https://github.com/UB-Mannheim/tesseract/wiki 下载安装'],
        );
      }

      // 先尝试中文+英文
      var result = await _runTesseract(imagePath, 'chi_sim+eng');
      if (result.text.trim().isEmpty) {
        // 降级到纯英文
        result = await _runTesseract(imagePath, 'eng');
      }

      diag.write('语言=${result.language}, 文字="${_truncateText(result.text, 80)}"');
      return OcrResult(
        text: result.text,
        blocks: [], // Tesseract 命令行不返回位置信息
        diagnostics: [diag.toString()],
      );
    } catch (e) {
      diag.write('识别异常: $e');
      return OcrResult(text: '', blocks: [], diagnostics: [diag.toString()]);
    }
  }

  Future<_TesseractResult> _runTesseract(String imagePath, String language) async {
    final result = await Process.run('tesseract', [
      imagePath,
      'stdout',
      '-l', language,
      '--psm', '6', // 自动分页
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
