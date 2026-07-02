import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';

import '../core/ocr/ocr_service.dart';

typedef DetectorLogger = void Function(String tag, String message);

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
  final DetectorLogger? logger;

  MemeDetector({this.logger});

  static void _log(String msg, {DetectorLogger? logger}) {
    if (logger != null) logger('MemeDetector', msg);
    debugPrint('[MemeDetector] $msg');
  }

  static const double _topBand = 0.30;
  static const double _bottomBand = 0.25;
  static const double _wideThreshold = 0.6;

  Future<MemeDetectionResult> detect(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      return MemeDetectionResult(filePath: imagePath, score: 0);
    }

    // GIF 直接放行，不参与 OCR/模糊检测
    if (imagePath.toLowerCase().endsWith('.gif')) {
      _log('detect: GIF $imagePath → auto pass');
      return MemeDetectionResult(filePath: imagePath, score: 0.85,
          hasWideText: true);
    }

    final fileSize = await file.length();
    if (fileSize < 1024 || fileSize > 2 * 1024 * 1024) {
      _log('detect: size filter $imagePath size=$fileSize');
      return MemeDetectionResult(filePath: imagePath, score: 0);
    }
    final dims = await _imageDimensions(imagePath);
    if (dims.$1 == 0 || dims.$2 == 0) {
      _log('detect: cannot read dimensions $imagePath');
    }

    _log('detect: OCR starting $imagePath ${dims.$1}x${dims.$2}');
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

    // ---- 位置分析 ----
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

    // ---- 质量/模糊分析 ----
    // 低质量图片（模糊/压缩/缩略图）加分——很多 meme 是低清重传的
    bool isLowQuality = false;
    if (imgW < 800 && imgH < 800) isLowQuality = true;     // 小尺寸
    else if (fileSize < 30 * 1024) isLowQuality = true;      // 小于 30KB
    else {
      // bytes per pixel 过低 = 高压缩/模糊
      final bpp = fileSize / (imgW * imgH);
      if (bpp < 0.5) isLowQuality = true;
    }

    bool isTooSmall = fileSize < 1 * 1024;            // < 1KB：图标/缩略图
    bool isTooLarge = fileSize > 2 * 1024 * 1024;       // > 2MB：高清照片

    // ---- 打分 ----
    _log('OCR done: "${ocrResult.text.substring(0, (ocrResult.text.length).clamp(0, 50))}" '
        '${ocrResult.blocks.length}blocks top=$hasTop bottom=$hasBottom wide=$hasWide');

    double score = 0;
    if (ocrResult.text.isNotEmpty) score += 0.25;
    if (hasTop && hasBottom)      score += 0.45;
    else if (hasTop || hasBottom) score += 0.30;
    else if (hasWide)             score += 0.20;
    else                          score += 0.10;
    if (hasWide)                  score += 0.10;

    // 文字长度惩罚：> 50 字偏向文档截图而非 meme
    if (ocrResult.text.length > 50) score -= 0.10;

    // 模糊/低质量加分：meme 特征
    if (isLowQuality)              score += 0.10;

    // 文件大小惩罚
    if (isTooSmall || isTooLarge)  score -= 0.15;

    score = score.clamp(0.0, 1.0);

    _log('score=${score.toStringAsFixed(2)} isMeme=${score >= 0.5} '
        '${imagePath.split('/').last}');

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
    if (!dir.existsSync()) {
      _log('scanDirectory: dir not found: $dirPath');
      return [];
    }
    final images = <String>[];
    const exts = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.heic', '.avif'};
    try {
      for (final entity in dir.listSync(recursive: true)) {
        if (entity is File) {
          final name = entity.path.toLowerCase();
          if (!exts.any((e) => name.endsWith(e))) continue;
          final size = entity.statSync().size;
          if (size < 1024 || size > 2 * 1024 * 1024) {
            _log('skip ${entity.path}: size=${size}B');
            continue;
          }
          images.add(entity.path);
        }
      }
    } catch (e) {
      _log('scanDirectory error: $e');
    }
    _log('scanDirectory found ${images.length} images in $dirPath');
    return images;
  }

  static Stream<ScanProgress> batchDetect(List<String> imagePaths, {DetectorLogger? logger}) async* {
    final detector = MemeDetector(logger: logger);
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
