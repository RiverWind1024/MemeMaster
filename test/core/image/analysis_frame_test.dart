import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/core/image/analysis_frame.dart';

img.Image _solid(int r, int g, int b, {int w = 4, int h = 4}) {
  final image = img.Image(width: w, height: h);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

/// 3 帧动图：红 → 绿 → 蓝
Uint8List _animatedGifBytes() {
  final first = _solid(255, 0, 0);
  first.addFrame(_solid(0, 255, 0));
  first.addFrame(_solid(0, 0, 255));
  return img.encodeGif(first);
}

void expectColor(img.Image image, int r, int g, int b) {
  final pixel = image.getPixel(0, 0);
  expect([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()], [r, g, b]);
}

void main() {
  group('selectAnalysisFrame', () {
    test('静态图返回自身', () {
      final image = _solid(10, 20, 30);
      final frame = selectAnalysisFrame(image);
      expect(identical(frame, image), isTrue);
    });

    test('3 帧 GIF 返回中间帧', () {
      final decoded = img.decodeImage(_animatedGifBytes())!;
      expect(decoded.numFrames, 3);
      expectColor(selectAnalysisFrame(decoded), 0, 255, 0);
    });
  });

  group('withAnalysisFrameFile', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('analysis_frame_test_');
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('非 GIF 直接透传原路径', () async {
      final path = '${tempDir.path}/static.png';
      await File(path).writeAsBytes(img.encodePng(_solid(1, 2, 3)));

      String? received;
      final result = await withAnalysisFrameFile<String>(path, (p) async {
        received = p;
        return 'ok';
      });

      expect(result, 'ok');
      expect(received, path);
      // 原文件未被删除
      expect(File(path).existsSync(), isTrue);
    });

    test('GIF 回调拿到中间帧，且临时文件会清理', () async {
      final gifPath = '${tempDir.path}/animated.gif';
      await File(gifPath).writeAsBytes(_animatedGifBytes());

      String? framePath;
      await withAnalysisFrameFile<void>(gifPath, (p) async {
        framePath = p;
        expect(p, isNot(gifPath));
        expect(File(p).existsSync(), isTrue);
        expectColor(img.decodeImage(await File(p).readAsBytes())!, 0, 255, 0);
      });

      expect(framePath, isNotNull);
      expect(File(framePath!).existsSync(), isFalse);
    });
  });
}
