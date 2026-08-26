import 'dart:io';

/// CLI OCR 异常：tesseract 不可用或执行失败时抛出。
class CliOcrException implements Exception {
  final String message;
  const CliOcrException(this.message);

  @override
  String toString() => 'CliOcrException: $message';
}

/// 纯 Dart OCR 服务：调用系统 `tesseract` CLI 识别图片文字。
///
/// GUI 的 `OcrService` 依赖 Flutter，CLI 无法复用，这里复刻其
/// Linux tesseract CLI fallback 逻辑（见 `lib/core/ocr/ocr_service.dart`）：
/// - 默认语言 `chi_sim+eng`
/// - 识别为空或语言包缺失时降级 `eng`
class CliOcr {
  /// OCR 语言（可配置），默认 chi_sim+eng。
  final String language;

  CliOcr({this.language = 'chi_sim+eng'});

  /// 检查 tesseract CLI 是否已安装。
  Future<bool> isInstalled() async {
    try {
      final result = await Process.run('tesseract', ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }

  /// 识别图片文件中的文字，返回去除首尾空白后的文本。
  ///
  /// 先尝试 [language]；若无结果或语言包不可用，降级尝试 `eng`。
  /// tesseract 不可用或 eng 也失败时抛出 [CliOcrException]。
  Future<String> recognize(String imagePath) async {
    final langs = language == 'eng' ? const ['eng'] : [language, 'eng'];
    Object? lastError;
    for (final lang in langs) {
      try {
        final text = await _run(imagePath, lang);
        if (text.isNotEmpty) return _normalize(text);
      } on CliOcrException catch (e) {
        lastError = e;
      }
    }
    if (lastError != null) throw lastError;
    return '';
  }

  Future<String> _run(String imagePath, String lang) async {
    final ProcessResult result;
    try {
      result = await Process.run('tesseract', [
        imagePath,
        'stdout',
        '-l', lang,
        '--psm', '3',
      ]);
    } on ProcessException catch (e) {
      throw CliOcrException('tesseract 不可用: $e');
    }

    if (result.exitCode != 0) {
      final stderr = (result.stderr as Object).toString().trim();
      throw CliOcrException(
        'tesseract 执行失败(exit=${result.exitCode}): $stderr',
      );
    }
    return (result.stdout as Object).toString().trim();
  }

  /// 清理 OCR 文本中 CJK 字符间多余空格（`那 老 子` → `那老子`）。
  String _normalize(String text) {
    if (text.isEmpty) return text;
    return text.replaceAll(
      RegExp(r'([\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af])\s+([\u4e00-\u9fff\u3040-\u309f\u30a0-\u30ff\uac00-\ud7af])'),
      r'$1$2',
    );
  }
}