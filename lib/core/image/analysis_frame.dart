import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../services/log_service.dart';

/// 分析用帧：多帧动图取中间一帧，静态图原样返回。
///
/// `image` 包解码 GIF 时会合成全部帧，因此这里没有额外解码成本。
img.Image selectAnalysisFrame(img.Image image) {
  if (image.numFrames <= 1) return image;
  return image.getFrame(image.numFrames ~/ 2);
}

/// 若 [imagePath] 是动图 GIF，则把中间帧写成临时 PNG 后交给 [action]；
/// 否则直接用原路径调用 [action]。临时文件在 [action] 结束后删除。
///
/// OCR 各平台实现（ML Kit / Tesseract / Vision）只接受文件路径，
/// 因此这里必须落一个临时文件。
Future<T> withAnalysisFrameFile<T>(
  String imagePath,
  Future<T> Function(String imagePath) action,
) async {
  if (!imagePath.toLowerCase().endsWith('.gif')) {
    return action(imagePath);
  }

  final decoded = img.decodeImage(await File(imagePath).readAsBytes());
  if (decoded == null || decoded.numFrames <= 1) {
    return action(imagePath);
  }

  final middleIndex = decoded.numFrames ~/ 2;
  final frame = decoded.getFrame(middleIndex);
  final tempPath = p.join(
    Directory.systemTemp.path,
    'meme_analysis_frame_${DateTime.now().microsecondsSinceEpoch}.png',
  );

  await File(tempPath).writeAsBytes(img.encodePng(frame), flush: true);
  LogService.instance.info(
    'AnalysisFrame',
    'GIF 取帧 $middleIndex/${decoded.numFrames}: $imagePath',
  );

  try {
    return await action(tempPath);
  } finally {
    try {
      await File(tempPath).delete();
    } catch (_) {
      // 临时文件清理失败不影响分析结果
    }
  }
}
