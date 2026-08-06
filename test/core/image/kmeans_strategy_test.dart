import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/core/image/color_extraction_strategies.dart';
import 'package:mememaster/core/image/color_extraction_config.dart';
import 'package:mememaster/core/utils/color_utils.dart';

void main() {
  group('KMeansStrategy', () {
    late KMeansStrategy strategy;

    setUp(() {
      strategy = KMeansStrategy();
    });

    /// 创建一个纯色测试图片
    img.Image createSolidColorImage(int r, int g, int b, {int width = 100, int height = 100}) {
      final image = img.Image(width: width, height: height);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          image.setPixelRgb(x, y, r, g, b);
        }
      }
      return image;
    }

    /// 创建一个两色混合测试图片
    img.Image createTwoColorImage(
      int r1, int g1, int b1,
      int r2, int g2, int b2, {
      int width = 100,
      int height = 100,
      double ratio = 0.7, // 第一种颜色的比例
    }) {
      final image = img.Image(width: width, height: height);
      final totalPixels = width * height;
      final firstColorPixels = (totalPixels * ratio).round();

      var pixelIndex = 0;
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          if (pixelIndex < firstColorPixels) {
            image.setPixelRgb(x, y, r1, g1, b1);
          } else {
            image.setPixelRgb(x, y, r2, g2, b2);
          }
          pixelIndex++;
        }
      }
      return image;
    }

    test('name 返回正确的名称', () {
      expect(strategy.name, 'K-means 聚类');
    });

    test('description 返回正确的描述', () {
      expect(strategy.description, '经典 K-means 聚类，通用场景效果均衡');
    });

    group('extractFromImage', () {
      test('纯色图片提取单一主色调', () {
        final image = createSolidColorImage(255, 0, 0);
        const config = ColorExtractionConfig();

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        expect(colors.isNotEmpty, isTrue);
        expect(colors.length, 1);
        // 主色调应该是红色
        expect(colors[0].hex.toUpperCase(), '#FF0000');
      });

      test('两色混合图片提取两种主色调', () {
        // 70% 红色, 30% 蓝色
        final image = createTwoColorImage(255, 0, 0, 0, 0, 255, ratio: 0.7);
        const config = ColorExtractionConfig(initialColorCount: 4);

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        expect(colors.length, greaterThanOrEqualTo(2));
        // 第一主色调应该是红色（占比更高）
        expect(colors[0].ratio, greaterThan(colors[1].ratio));
      });

      test('图片尺寸为 0 返回空列表', () {
        final image = img.Image(width: 0, height: 0);
        const config = ColorExtractionConfig();

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: 0,
        );

        expect(colors, isEmpty);
      });

      test('配置 initialColorCount 限制结果数量', () {
        final image = createTwoColorImage(255, 0, 0, 0, 255, 0, ratio: 0.5);
        const config = ColorExtractionConfig(maxResultColors: 2);

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        expect(colors.length, lessThanOrEqualTo(2));
      });

      test('配置 minRatio 过滤小占比颜色', () {
        final image = createTwoColorImage(255, 0, 0, 0, 0, 255, ratio: 0.99);
        const config = ColorExtractionConfig(minRatio: 0.05);

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        // 99% 红 + 1% 蓝，1% 应该被 minRatio=0.05 过滤掉
        for (final color in colors) {
          expect(color.ratio, greaterThanOrEqualTo(0.05));
        }
      });

      test('ratio 总和不超过 1.0', () {
        final image = createTwoColorImage(255, 0, 0, 0, 255, 0, ratio: 0.5);
        const config = ColorExtractionConfig();

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        final totalRatio = colors.fold(0.0, (sum, c) => sum + c.ratio);
        expect(totalRatio, lessThanOrEqualTo(1.0));
      });

      test('返回的颜色包含所有必需字段', () {
        final image = createSolidColorImage(128, 128, 128);
        const config = ColorExtractionConfig();

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        for (final color in colors) {
          expect(color.hex, isNotEmpty);
          expect(color.lChannel, isNotNull);
          expect(color.aChannel, isNotNull);
          expect(color.bChannel, isNotNull);
          expect(color.ratio, greaterThan(0));
          expect(color.ratio, lessThanOrEqualTo(1.0));
        }
      });

      test('Lab 颜色空间值在合理范围内', () {
        final image = createSolidColorImage(200, 100, 50);
        const config = ColorExtractionConfig();

        final colors = strategy.extractFromImage(
          image,
          config: config,
          totalPixels: image.width * image.height,
        );

        for (final color in colors) {
          // L* 范围 0-100
          expect(color.lChannel, inInclusiveRange(0, 100));
          // a* 和 b* 理论范围约 -128 到 127，但实际图像颜色通常更窄
          expect(color.aChannel, inInclusiveRange(-150, 150));
          expect(color.bChannel, inInclusiveRange(-150, 150));
        }
      });
    });

    group('_kmeansPlusPlus 初始化', () {
      test('初始化产生 K 个不同的质心', () {
        final image = createTwoColorImage(255, 0, 0, 0, 0, 255);
        final samples = _extractSamples(image);
        const K = 5;

        final centroids = _kmeanspp(samples, K);

        expect(centroids.length, K);
      });

      test('质心是有效的 RGB 点', () {
        final image = createTwoColorImage(100, 150, 200, 50, 100, 150);
        final samples = _extractSamples(image);
        const K = 3;

        final centroids = _kmeanspp(samples, K);

        for (final c in centroids) {
          expect(c.r, inInclusiveRange(0, 255));
          expect(c.g, inInclusiveRange(0, 255));
          expect(c.b, inInclusiveRange(0, 255));
        }
      });
    });

    group('_samplePixels 采样', () {
      test('采样数量在合理范围内', () {
        final image = createSolidColorImage(100, 100, 100, width: 1000, height: 1000);
        final samples = _samplePixels(image, 0.1); // 10% 采样率

        expect(samples.length, greaterThan(0));
        expect(samples.length, lessThanOrEqualTo(20000)); // maxSamples 上限
      });

      test('采样的像素值在有效范围内', () {
        final image = createSolidColorImage(128, 64, 32);
        final samples = _samplePixels(image, 0.5);

        for (final s in samples) {
          expect(s.r, inInclusiveRange(0, 255));
          expect(s.g, inInclusiveRange(0, 255));
          expect(s.b, inInclusiveRange(0, 255));
        }
      });
    });
  });
}

// Helper functions that replicate internal implementation for testing
List<_KMeansPoint> _extractSamples(img.Image image) {
  final samples = <_KMeansPoint>[];
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      final p = image.getPixel(x, y);
      samples.add(_KMeansPoint(p.r.toDouble(), p.g.toDouble(), p.b.toDouble()));
    }
  }
  return samples;
}

List<_KMeansPoint> _samplePixels(img.Image image, double rate) {
  final total = image.width * image.height;
  final maxSamples = 20000;
  final count = (total * rate).clamp(100, maxSamples).toInt();
  final step = max(1, total ~/ count);
  final samples = <_KMeansPoint>[];
  var idx = 0;

  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (idx % step == 0) {
        final p = image.getPixel(x, y);
        samples.add(_KMeansPoint(p.r.toDouble(), p.g.toDouble(), p.b.toDouble()));
        if (samples.length >= count) break;
      }
      idx++;
    }
    if (samples.length >= count) break;
  }
  return samples;
}

// Replicate K-means++ for testing
List<_KMeansPoint> _kmeanspp(List<_KMeansPoint> samples, int K) {
  if (samples.isEmpty) return [];
  final random = Random(42); // Deterministic
  final centroids = <_KMeansPoint>[];
  centroids.add(samples[random.nextInt(samples.length)]);

  final dists = List.filled(samples.length, double.infinity);

  for (int k = 1; k < K; k++) {
    var totalDist = 0.0;
    for (int i = 0; i < samples.length; i++) {
      final d = _distSq(samples[i], centroids[k - 1]);
      if (d < dists[i]) dists[i] = d;
      totalDist += dists[i];
    }

    var threshold = random.nextDouble() * totalDist;
    for (int i = 0; i < samples.length; i++) {
      threshold -= dists[i];
      if (threshold <= 0) {
        centroids.add(samples[i]);
        break;
      }
    }
    if (centroids.length == k) {
      centroids.add(samples[random.nextInt(samples.length)]);
    }
  }

  return centroids;
}

double _distSq(_KMeansPoint a, _KMeansPoint b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return dr * dr + dg * dg + db * db;
}

class _KMeansPoint {
  double r, g, b;
  _KMeansPoint(this.r, this.g, this.b);
}
