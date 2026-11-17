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

void expectColor(img.Image image, int r, int g, int b, {int x = 0, int y = 0}) {
  final pixel = image.getPixel(x, y);
  expect([pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()], [r, g, b]);
}

void main() {
  group('selectAnalysisFrames', () {
    test('静态图返回自身', () {
      final image = _solid(10, 20, 30);
      final frames = selectAnalysisFrames(image);
      expect(frames, hasLength(1));
      expect(identical(frames.first, image), isTrue);
    });

    test('3 帧 GIF 返回首帧和中间帧', () {
      final decoded = img.decodeImage(_animatedGifBytes())!;
      expect(decoded.numFrames, 3);

      final frames = selectAnalysisFrames(decoded);
      expect(frames, hasLength(2));
      expectColor(frames[0], 255, 0, 0);
      expectColor(frames[1], 0, 255, 0);
    });

    test('2 帧 GIF 返回首帧和末帧（中间索引为 1）', () {
      final few = _solid(255, 0, 0);
      few.addFrame(_solid(0, 0, 255));

      final frames = selectAnalysisFrames(img.decodeImage(img.encodeGif(few))!);
      expect(frames, hasLength(2));
      expectColor(frames[0], 255, 0, 0);
      expectColor(frames[1], 0, 0, 255);
    });
  });

  group('combineAnalysisFrames', () {
    test('单帧原样返回', () {
      final image = _solid(1, 2, 3);
      expect(identical(combineAnalysisFrames([image]), image), isTrue);
    });

    test('两帧垂直拼接，尺寸与像素正确', () {
      final red = _solid(255, 0, 0);
      final green = _solid(0, 255, 0);

      final combined = combineAnalysisFrames([red, green]);
      expect(combined.width, 4);
      expect(combined.height, 8);
      expectColor(combined, 255, 0, 0, y: 1);
      expectColor(combined, 0, 255, 0, y: 5);
    });
  });

  group('withAnalysisFramesFiles', () {
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

      List<String>? received;
      final result = await withAnalysisFramesFiles<String>(path, (paths) async {
        received = paths;
        return 'ok';
      });

      expect(result, 'ok');
      expect(received, [path]);
      // 原文件未被删除
      expect(File(path).existsSync(), isTrue);
    });

    test('GIF 回调拿到首帧和中间帧，且临时文件会清理', () async {
      final gifPath = '${tempDir.path}/animated.gif';
      await File(gifPath).writeAsBytes(_animatedGifBytes());

      List<String>? framePaths;
      await withAnalysisFramesFiles<void>(gifPath, (paths) async {
        framePaths = paths;
        expect(paths, hasLength(2));
        expect(paths, isNot(contains(gifPath)));

        expectColor(img.decodeImage(await File(paths[0]).readAsBytes())!, 255, 0, 0);
        expectColor(img.decodeImage(await File(paths[1]).readAsBytes())!, 0, 255, 0);
      });

      expect(framePaths, isNotNull);
      for (final path in framePaths!) {
        expect(File(path).existsSync(), isFalse);
      }
    });
  });
}
