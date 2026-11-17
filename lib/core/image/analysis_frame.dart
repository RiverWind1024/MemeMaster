import 'dart:io';
import 'dart:math';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../services/log_service.dart';

/// 分析用帧：多帧动图取「首帧 + 中间帧」，静态图只返回自身。
///
/// `image` 包解码 GIF 时会合成全部帧，因此这里没有额外解码成本。
List<img.Image> selectAnalysisFrames(img.Image image) {
  if (image.numFrames <= 1) return [image];

  final middleIndex = image.numFrames ~/ 2;
  if (middleIndex == 0) return [image];
  return [image.getFrame(0), image.getFrame(middleIndex)];
}

/// 把多帧垂直拼成一张图，供只接受单图的分析流程（颜色提取、视觉 AI）使用。
///
/// GIF 合成帧尺寸一致，拼接后两帧像素各占一半，K-means 的比例即两帧的综合结果。
img.Image combineAnalysisFrames(List<img.Image> frames) {
  if (frames.length == 1) return frames.first;

  final width = frames.map((f) => f.width).reduce(max);
  final height = frames.fold<int>(0, (sum, f) => sum + f.height);
  final canvas = img.Image(width: width, height: height);

  var y = 0;
  for (final frame in frames) {
    img.compositeImage(canvas, frame, dstX: 0, dstY: y);
    y += frame.height;
  }
  return canvas;
}

/// 若 [imagePath] 是动图 GIF，则把首帧和中间帧写成临时 PNG 后交给 [action]；
/// 否则直接用原路径调用。临时文件在 [action] 结束后删除。
///
/// OCR 各平台实现（ML Kit / Tesseract / Vision）只接受文件路径，
/// 因此这里必须落临时文件。
Future<T> withAnalysisFramesFiles<T>(
  String imagePath,
  Future<T> Function(List<String> framePaths) action,
) async {
  if (!imagePath.toLowerCase().endsWith('.gif')) {
    return action([imagePath]);
  }

  final decoded = img.decodeImage(await File(imagePath).readAsBytes());
  if (decoded == null || decoded.numFrames <= 1) {
    return action([imagePath]);
  }

  final frames = selectAnalysisFrames(decoded);
  final tempFiles = <File>[];
  try {
    for (var i = 0; i < frames.length; i++) {
      final tempPath = p.join(
        Directory.systemTemp.path,
        'meme_analysis_frame_${DateTime.now().microsecondsSinceEpoch}_$i.png',
      );
      await File(tempPath).writeAsBytes(img.encodePng(frames[i]), flush: true);
      tempFiles.add(File(tempPath));
    }

    LogService.instance.info(
      'AnalysisFrame',
      'GIF 取帧 0,${decoded.numFrames ~/ 2}/${decoded.numFrames}: $imagePath',
    );

    return await action(tempFiles.map((f) => f.path).toList());
  } finally {
    for (final file in tempFiles) {
      try {
        await file.delete();
      } catch (_) {
        // 临时文件清理失败不影响分析结果
      }
    }
  }
}
