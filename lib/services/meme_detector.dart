import 'dart:io';
import 'dart:ui' show Rect;

import '../core/ocr/ocr_service.dart';

class MemeDetectionResult {
  final String filePath;
  final double score;
  final String? text;
  final bool hasTextAtTop;
  final bool hasTextAtBottom;
  final bool hasWideText;

  bool get isMeme => score >= 0.5;

  const MemeDetectionResult({
    required this.filePath,
    required this.score,
    this.text,
    this.hasTextAtTop = false,
    this.hasTextAtBottom = false,
    this.hasWideText = false,
  });
}

class ScanProgress {
  final int total;
  final int completed;
  final int memesFound;
  final int textFound;
  final int noText;
  final String? currentFile;

  const ScanProgress({
    this.total = 0,
    this.completed = 0,
    this.memesFound = 0,
    this.textFound = 0,
    this.noText = 0,
    this.currentFile,
  });

  bool get isFinished => completed >= total;
}

/// OCR + 文本位置分析判断 meme，阈值 ≥0.5
class MemeDetector {
  static const double _topBand = 0.30;
  static const double _bottomBand = 0.25;
  static const double _wideThreshold = 0.6;

  Future<MemeDetectionResult> detect(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return MemeDetectionResult(filePath: imagePath, score: 0);
    }

    final dims = await _imageDimensions(imagePath);
    final imgW = dims.$1;
    final imgH = dims.$2;

    final ocr = OcrService();
    OcrResult ocrResult;
    try {
      ocrResult = await ocr.recognizeImage(imagePath);
    } finally {
      ocr.close();
    }

    if (ocrResult.isEmpty) {
      return MemeDetectionResult(filePath: imagePath, score: 0);
    }

    final blocks = ocrResult.blocks;
    if (imgH == 0 || blocks.isEmpty) {
      return MemeDetectionResult(filePath: imagePath, score: 0.25, text: ocrResult.text);
    }

    bool hasTop = false, hasBottom = false, hasWide = false;
    final topY = (imgH * _topBand).toInt();
    final bottomY = (imgH * (1 - _bottomBand)).toInt();
    final widePx = (imgW * _wideThreshold).toInt();

    for (final b in blocks) {
      final r = b.boundingBox;
      if (r.top < topY || r.center.dy < topY) hasTop = true;
      if (r.bottom > bottomY || r.center.dy > bottomY) hasBottom = true;
      if (r.width > widePx) hasWide = true;
    }

    double score = 0;
    if (ocrResult.text.isNotEmpty) score += 0.25;
    if (hasTop && hasBottom)      score += 0.45;
    else if (hasTop || hasBottom) score += 0.30;
    else if (hasWide)             score += 0.20;
    else                          score += 0.10;
    if (hasWide)                  score += 0.10;
    if (ocrResult.text.length > 300)      score -= 0.15;
    else if (ocrResult.text.length > 150) score -= 0.05;

    score = score.clamp(0.0, 1.0);

    return MemeDetectionResult(
      filePath: imagePath,
      score: score,
      text: ocrResult.text.length > 200
          ? '${ocrResult.text.substring(0, 200)}...'
          : ocrResult.text,
      hasTextAtTop: hasTop,
      hasTextAtBottom: hasBottom,
      hasWideText: hasWide,
    );
  }

  Future<(int, int)> _imageDimensions(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.length < 24) return (0, 0);
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
        int off = 2;
        while (off + 9 < bytes.length) {
          if (bytes[off] == 0xFF && (bytes[off + 1] == 0xC0 || bytes[off + 1] == 0xC2)) {
            return ((bytes[off + 7] << 8) | bytes[off + 8],
                    (bytes[off + 5] << 8) | bytes[off + 6]);
          }
          off += 2 + ((bytes[off + 2] << 8) | bytes[off + 3]);
        }
      } else if (bytes[0] == 0x89 && bytes[1] == 0x50) {
        return ((bytes[20] << 8) | bytes[21],
                (bytes[16] << 8) | bytes[17]);
      } else if (bytes[0] == 0x52 && bytes[1] == 0x49) {
        return (((bytes[26] << 8) | bytes[27]) & 0x3FFF,
                ((bytes[28] << 8) | bytes[29]) & 0x3FFF);
      } else if (bytes[0] == 0x47 && bytes[1] == 0x49) {
        return (bytes[6] | (bytes[7] << 8),
                bytes[8] | (bytes[9] << 8));
      } else if (bytes[0] == 0x42 && bytes[1] == 0x4D) {
        return (bytes[18] | (bytes[19] << 8) | (bytes[20] << 16) | (bytes[21] << 24),
                bytes[22] | (bytes[23] << 8) | (bytes[24] << 16) | (bytes[25] << 24));
      }
    } catch (_) {}
    return (0, 0);
  }

  static List<String> scanDirectory(String dirPath) {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return [];
    final images = <String>[];
    const exts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.avif'};
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final name = entity.path.toLowerCase();
          if (exts.any((e) => name.endsWith(e))) images.add(entity.path);
        }
      }
    } catch (_) {}
    return images;
  }

  static Stream<ScanProgress> batchDetect(List<String> imagePaths) async* {
    final detector = MemeDetector();
    int memesFound = 0, textFound = 0, noText = 0, completed = 0;
    final total = imagePaths.length;
    for (int i = 0; i < imagePaths.length; i += 5) {
      final results = await Future.wait(
        imagePaths.skip(i).take(5).map((p) => detector.detect(p)));
      for (final r in results) {
        completed++;
        if (r.isMeme)      memesFound++;
        else if (r.text != null && r.text!.isNotEmpty) textFound++;
        else                noText++;
        yield ScanProgress(total: total, completed: completed,
            memesFound: memesFound, textFound: textFound, noText: noText,
            currentFile: r.filePath);
      }
    }
    yield ScanProgress(total: total, completed: completed,
        memesFound: memesFound, textFound: textFound, noText: noText);
  }
}
