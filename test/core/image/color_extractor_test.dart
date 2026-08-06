import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/core/image/color_extractor.dart';
import 'package:mememaster/core/image/color_extraction_config.dart';
import 'package:mememaster/core/utils/color_utils.dart';

void main() {
  group('ColorExtractor', () {
    test('默认构造函数设置默认配置', () {
      const extractor = ColorExtractor();
      expect(extractor.defaultConfig.method, ColorExtractionMethod.kmeans);
    });

    test('构造函数接受自定义默认配置', () {
      const config = ColorExtractionConfig(
        initialColorCount: 8,
        maxIterations: 50,
      );
      final extractor = ColorExtractor(defaultConfig: config);
      expect(extractor.defaultConfig.initialColorCount, 8);
      expect(extractor.defaultConfig.maxIterations, 50);
    });

    group('extract', () {
      test('文件不存在时抛出 FileSystemException', () async {
        final extractor = ColorExtractor();

        expect(
          () => extractor.extract('/nonexistent/path/image.png'),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('extractFromImage', () {
      img.Image _createSolidColorImage(int r, int g, int b,
          {int width = 100, int height = 100}) {
        final image = img.Image(width: width, height: height);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            image.setPixelRgb(x, y, r, g, b);
          }
        }
        return image;
      }

      test('从解码的图片中提取主色调', () {
        final image = _createSolidColorImage(255, 255, 0); // 黄色
        final extractor = ColorExtractor();

        final colors = extractor.extractFromImage(
          image,
          config: const ColorExtractionConfig(),
        );

        expect(colors.isNotEmpty, isTrue);
        // 黄色 RGB(255, 255, 0) -> hex 应该是 #FFFF00
        expect(colors[0].hex.toUpperCase(), '#FFFF00');
      });

      test('空图片返回空列表', () {
        final image = img.Image(width: 0, height: 0);
        final extractor = ColorExtractor();

        final colors = extractor.extractFromImage(
          image,
          config: const ColorExtractionConfig(),
        );

        expect(colors, isEmpty);
      });

      test('提取的颜色包含正确的 Lab 值', () {
        final image = _createSolidColorImage(0, 0, 255);
        final extractor = ColorExtractor();

        final colors = extractor.extractFromImage(
          image,
          config: const ColorExtractionConfig(),
        );

        expect(colors.isNotEmpty, isTrue);
        final color = colors[0];
        expect(color.lChannel, inInclusiveRange(0, 100));
        expect(color.aChannel, inInclusiveRange(-150, 150));
        expect(color.bChannel, inInclusiveRange(-150, 150));
      });

      test('提取的颜色 ratio 总和不超过 1', () {
        final image = img.Image(width: 100, height: 100);
        final random = Random(42);
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 100; x++) {
            image.setPixelRgb(
              x, y,
              random.nextInt(256),
              random.nextInt(256),
              random.nextInt(256),
            );
          }
        }
        final extractor = ColorExtractor();

        final colors = extractor.extractFromImage(
          image,
          config: const ColorExtractionConfig(),
        );

        final totalRatio = colors.fold(0.0, (sum, c) => sum + c.ratio);
        expect(totalRatio, lessThanOrEqualTo(1.0));
      });

      test('两色混合图片提取两种主色调', () {
        final image = img.Image(width: 100, height: 100);
        final totalPixels = 100 * 100;
        final firstColorPixels = (totalPixels * 0.7).round();

        var pixelIndex = 0;
        for (var y = 0; y < 100; y++) {
          for (var x = 0; x < 100; x++) {
            if (pixelIndex < firstColorPixels) {
              image.setPixelRgb(x, y, 255, 0, 0);
            } else {
              image.setPixelRgb(x, y, 0, 0, 255);
            }
            pixelIndex++;
          }
        }

        final extractor = ColorExtractor();
        final colors = extractor.extractFromImage(
          image,
          config: const ColorExtractionConfig(initialColorCount: 4),
        );

        expect(colors.length, greaterThanOrEqualTo(2));
        expect(colors[0].ratio, greaterThan(colors[1].ratio));
      });
    });
  });

  group('ColorExtractionConfig', () {
    test('默认配置值', () {
      const config = ColorExtractionConfig();
      expect(config.method, ColorExtractionMethod.kmeans);
      expect(config.initialColorCount, 32);
      expect(config.maxIterations, 20);
      expect(config.sampleRate, 0.2);
      expect(config.mergeThreshold, 12.0);
      expect(config.minRatio, 0.03);
      expect(config.maxResultColors, 8);
    });

    test('自定义配置', () {
      const config = ColorExtractionConfig(
        method: ColorExtractionMethod.kmeans,
        initialColorCount: 10,
        maxIterations: 50,
        sampleRate: 0.15,
        mergeThreshold: 20.0,
        minRatio: 0.05,
        maxResultColors: 3,
      );
      expect(config.initialColorCount, 10);
      expect(config.maxIterations, 50);
      expect(config.sampleRate, 0.15);
      expect(config.mergeThreshold, 20.0);
      expect(config.minRatio, 0.05);
      expect(config.maxResultColors, 3);
    });
  });

  group('DominantColor', () {
    test('创建有效的 DominantColor', () {
      // DominantColor.hex 直接存储传入的值，不做转换
      const color = DominantColor(
        hex: '#FF5733',  // 保持传入的大小写
        lChannel: 50.0,
        aChannel: 60.0,
        bChannel: 70.0,
        ratio: 0.3,
      );
      expect(color.hex, '#FF5733');  // 保持原样
      expect(color.lChannel, 50.0);
      expect(color.aChannel, 60.0);
      expect(color.bChannel, 70.0);
      expect(color.ratio, 0.3);
    });
  });
}
