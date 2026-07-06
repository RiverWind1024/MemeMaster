import 'dart:math';

import 'package:image/image.dart' as img;

import '../utils/color_utils.dart';
import 'color_extraction_config.dart';

// =====================================================================
// 抽象策略接口
// =====================================================================

abstract class ColorExtractionStrategy {
  String get name;
  String get description;

  /// 从解码后的图片中提取主色调
  ///
  /// [config] 包含该算法所需的全部参数
  /// [totalPixels] 是图片像素总数，用于计算占比
  List<DominantColor> extractFromImage(
    img.Image image, {
    required ColorExtractionConfig config,
    required int totalPixels,
  });
}

// =====================================================================
// K-means 聚类
//
// 从图片中采样像素 -> K-means++ 初始化 -> 迭代聚类 -> Lab 合并。
//
// 适合：通用场景，效果均衡
// 优点：经典算法，调参直观
// =====================================================================

class KMeansStrategy extends ColorExtractionStrategy {
  @override
  String get name => 'K-means 聚类';

  @override
  String get description => '经典 K-means 聚类，通用场景效果均衡';

  final Random _random = Random();

  @override
  List<DominantColor> extractFromImage(
    img.Image image, {
    required ColorExtractionConfig config,
    required int totalPixels,
  }) {
    final K = config.initialColorCount.clamp(4, 128);
    final maxIter = config.maxIterations.clamp(5, 100);

    // ---- 1. 采样像素 ----
    final samples = _samplePixels(image, config.sampleRate);

    if (samples.isEmpty || samples.length < K) {
      // 采样点不足，回退到直接返回空
      return [];
    }

    // ---- 2. K-means++ 初始化 ----
    var centroids = _kmeansPlusPlus(samples, K);

    final assignments = List.filled(samples.length, 0);

    // ---- 3. 迭代 ----
    for (int iter = 0; iter < maxIter; iter++) {
      // Assignment step
      for (int i = 0; i < samples.length; i++) {
        int bestIdx = 0;
        double bestDist = _distSq(samples[i], centroids[0]);
        for (int k = 1; k < K; k++) {
          final d = _distSq(samples[i], centroids[k]);
          if (d < bestDist) {
            bestDist = d;
            bestIdx = k;
          }
        }
        assignments[i] = bestIdx;
      }

      // Update step
      final sums = List.generate(K, (_) => _KMeansPoint(0, 0, 0));
      final counts = List.filled(K, 0);
      for (int i = 0; i < samples.length; i++) {
        final k = assignments[i];
        sums[k].r += samples[i].r;
        sums[k].g += samples[i].g;
        sums[k].b += samples[i].b;
        counts[k]++;
      }

      var changed = false;
      for (int k = 0; k < K; k++) {
        if (counts[k] > 0) {
          final newCentroid = _KMeansPoint(
            sums[k].r / counts[k],
            sums[k].g / counts[k],
            sums[k].b / counts[k],
          );
          if (_distSq(newCentroid, centroids[k]) > 0.5) {
            changed = true;
          }
          centroids[k] = newCentroid;
        }
      }

      // Handle empty clusters: reinitialize to random sample
      for (int k = 0; k < K; k++) {
        if (counts[k] == 0) {
          centroids[k] = _KMeansPoint(
            samples[_random.nextInt(samples.length)].r.toDouble(),
            samples[_random.nextInt(samples.length)].g.toDouble(),
            samples[_random.nextInt(samples.length)].b.toDouble(),
          );
          changed = true;
        }
      }

      if (!changed) break;
    }

    // ---- 4. 构建结果 ----
    final finalCounts = List.filled(K, 0);
    for (int i = 0; i < samples.length; i++) {
      finalCounts[assignments[i]]++;
    }
    // 按样本量占比估算到整图
    final sampleRatio = samples.length / totalPixels;

    var quantizedColors = <_QuantizedColor>[];
    for (int k = 0; k < K; k++) {
      if (finalCounts[k] == 0) continue;
      quantizedColors.add(_QuantizedColor(
        rgb: ColorRgb(
          centroids[k].r.round().clamp(0, 255),
          centroids[k].g.round().clamp(0, 255),
          centroids[k].b.round().clamp(0, 255),
        ),
        count: (finalCounts[k] / sampleRatio).round(),
      ));
    }

    quantizedColors.sort((a, b) => b.count.compareTo(a.count));
    quantizedColors = _mergeSimilarColors(quantizedColors, config);
    return _colorsToDominant(quantizedColors, totalPixels, config);
  }

  /// K-means++ 初始化：依次选取距离已有质心最远的点
  List<_KMeansPoint> _kmeansPlusPlus(List<_KMeansPoint> samples, int K) {
    final centroids = <_KMeansPoint>[];
    // 随机选第一个
    centroids.add(samples[_random.nextInt(samples.length)]);

    final dists = List.filled(samples.length, double.infinity);

    for (int k = 1; k < K; k++) {
      var totalDist = 0.0;
      for (int i = 0; i < samples.length; i++) {
        final d = _distSq(samples[i], centroids[k - 1]);
        if (d < dists[i]) dists[i] = d;
        totalDist += dists[i];
      }

      // 轮盘赌选下一个质心
      var threshold = _random.nextDouble() * totalDist;
      for (int i = 0; i < samples.length; i++) {
        threshold -= dists[i];
        if (threshold <= 0) {
          centroids.add(samples[i]);
          break;
        }
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
}

/// K-means 内部点类型（double 精度）
class _KMeansPoint {
  double r, g, b;
  _KMeansPoint(this.r, this.g, this.b);
}

// =====================================================================
// 共享工具函数
// =====================================================================

/// 从图片中均匀采样像素
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
        samples.add(_KMeansPoint(
          p.r.toInt().toDouble(),
          p.g.toInt().toDouble(),
          p.b.toInt().toDouble(),
        ));
        if (samples.length >= count) break;
      }
      idx++;
    }
    if (samples.length >= count) break;
  }
  return samples;
}

/// 合并 LAB 空间中色差 [mergeThreshold] 以内的相似颜色
List<_QuantizedColor> _mergeSimilarColors(
    List<_QuantizedColor> colors, ColorExtractionConfig config) {
  if (colors.length <= 1) return colors;

  final merged = <_QuantizedColor>[];
  final used = List<bool>.filled(colors.length, false);

  for (var i = 0; i < colors.length; i++) {
    if (used[i]) continue;

    var totalCount = colors[i].count;
    var rSum = colors[i].rgb.r * colors[i].count;
    var gSum = colors[i].rgb.g * colors[i].count;
    var bSum = colors[i].rgb.b * colors[i].count;
    used[i] = true;

    for (var j = i + 1; j < colors.length; j++) {
      if (used[j]) continue;

      final d = _deltaEInt(colors[i].rgb, colors[j].rgb);
      if (d < config.mergeThreshold) {
        totalCount += colors[j].count;
        rSum += colors[j].rgb.r * colors[j].count;
        gSum += colors[j].rgb.g * colors[j].count;
        bSum += colors[j].rgb.b * colors[j].count;
        used[j] = true;
      }
    }

    merged.add(_QuantizedColor(
      rgb: ColorRgb(
        (rSum / totalCount).round(),
        (gSum / totalCount).round(),
        (bSum / totalCount).round(),
      ),
      count: totalCount,
    ));
  }

  merged.sort((a, b) => b.count.compareTo(a.count));
  return merged;
}

/// 快速 RGB 近似 ΔE（避免重复 Lab 转换的开销）
double _deltaEInt(ColorRgb a, ColorRgb b) {
  final dr = a.r - b.r;
  final dg = a.g - b.g;
  final db = a.b - b.b;
  return sqrt((2 * dr * dr) + (4 * dg * dg) + (3 * db * db));
}

/// 将 [_QuantizedColor] 列表转换为 [DominantColor] 列表，
/// 过滤低于 [minRatio] 的颜色，取前 [maxResultColors] 个
List<DominantColor> _colorsToDominant(
    List<_QuantizedColor> colors, int totalPixels, ColorExtractionConfig config) {
  final results = <DominantColor>[];
  for (final c in colors) {
    final ratio = c.count / totalPixels;
    if (ratio < config.minRatio) break; // 已按降序排序，后续更小

    final lab = rgbToLab(c.rgb);
    results.add(DominantColor(
      hex: c.rgb.hex,
      lChannel: lab.l,
      aChannel: lab.a,
      bChannel: lab.b,
      ratio: ratio,
    ));
    if (results.length >= config.maxResultColors) break;
  }
  return results;
}

// =====================================================================
// 内部数据类型
// =====================================================================

class _QuantizedColor {
  final ColorRgb rgb;
  final int count;
  const _QuantizedColor({required this.rgb, required this.count});
}
