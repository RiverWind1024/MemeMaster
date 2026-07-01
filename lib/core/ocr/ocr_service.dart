import 'dart:io';
import 'dart:ui' show Rect;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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

/// OCR 识别服务（Google ML Kit Text Recognition）
///
/// 支持中文和英文文本识别。使用相机或图片文件进行 OCR。
/// 每次使用后必须调用 [close] 释放资源。
class OcrService {
  /// 识图图片文件中的文字
  ///
  /// [diagnostics] 不为空时，会填充各脚本的尝试结果（用于 LogViewer 诊断）。
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

  /// 用指定脚本识别一次，返回结果+诊断信息
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

  /// 释放 TextRecognizer 资源（每个 _tryRecognize 已自行 close）
  void close() {}
}
