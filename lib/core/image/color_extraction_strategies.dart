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
// 策略 1: NeuralQuantizer（Kohonen SOM 神经网络量化）
//
// 使用 package:image 内置的 NeuralQuantizer 将图片降色到 N 色，
// 再统计每个量化色的像素占比、合并相似色、过滤低占比颜色。
//
// 适合：渐变丰富的照片类图片
// =====================================================================

class NeuralQuantizerStrategy extends ColorExtractionStrategy {
  @override
  String get name => '神经网络量化';

  @override
  String get description => 'Kohonen SOM 神经网络降色 + 聚类合并，适合渐变丰富的图片';

  @override
  List<DominantColor> extractFromImage(
    img.Image image, {
    required ColorExtractionConfig config,
    required int totalPixels,
  }) {
    // ---- Pass 1: 神经网络量化降色 ----
    final quantizer =
        img.NeuralQuantizer(image, numberOfColors: config.initialColorCount);

    // 统计每个量化色的像素数
    final colorCounts = <int, int>{};
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final idx = quantizer.getColorIndexRgb(
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
        colorCounts[idx] = (colorCounts[idx] ?? 0) + 1;
      }
    }

    // 构建量化色列表
    var quantizedColors = <_QuantizedColor>[];
    for (final entry in colorCounts.entries) {
      final r = quantizer.palette.get(entry.key, 0) as int;
      final g = quantizer.palette.get(entry.key, 1) as int;
      final b = quantizer.palette.get(entry.key, 2) as int;
      quantizedColors.add(_QuantizedColor(
        rgb: ColorRgb(r, g, b),
        count: entry.value,
      ));
    }

    // 按像素数降序排列
    quantizedColors.sort((a, b) => b.count.compareTo(a.count));

    // ---- Pass 2: 合并相似颜色 ----
    quantizedColors = _mergeSimilarColors(quantizedColors, config);

    // ---- Pass 3: 阈值过滤 + Lab 转换 ----
    return _colorsToDominant(quantizedColors, totalPixels, config);
  }
}

// =====================================================================
// 策略 2: Histogram（RGB 直方图分桶）
//
// 将 RGB 立方体划分为 N×N×N 个桶，统计每个桶内像素数量，
// 以桶内平均颜色作为候选色，合并相似色，过滤低占比颜色。
//
// 适合：快速粗略提取，扁平风格图片
// 优点：速度极快（O(pixels) 无迭代），无需外部依赖
// =====================================================================

class HistogramStrategy extends ColorExtractionStrategy {
  @override
  String get name => '直方图分桶';

  @override
  String get description => 'RGB 立方体分桶统计，速度快，适合扁平风格图片';

  @override
  List<DominantColor> extractFromImage(
    img.Image image, {
    required ColorExtractionConfig config,
    required int totalPixels,
  }) {
    final bins = config.histogramBins.clamp(2, 32);
    final binSize = 256 / bins;

    // 桶数据结构：key = (rIdx * bins + gIdx) * bins + bIdx
    // value = {count, rSum, gSum, bSum}
    final bucketMap = <int, _HistogramBucket>{};

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final r = pixel.r.toInt();
        final g = pixel.g.toInt();
        final b = pixel.b.toInt();
        final rIdx = (r / binSize).floor().clamp(0, bins - 1);
        final gIdx = (g / binSize).floor().clamp(0, bins - 1);
        final bIdx = (b / binSize).floor().clamp(0, bins - 1);
        final key = ((rIdx * bins) + gIdx) * bins + bIdx;

        bucketMap.putIfAbsent(key, () => _HistogramBucket());
        final bucket = bucketMap[key]!;
        bucket.count++;
        bucket.rSum += r;
        bucket.gSum += g;
        bucket.bSum += b;
      }
    }

    // 转换为候选色列表（桶内平均颜色）
    var candidates = <_QuantizedColor>[];
    for (final bucket in bucketMap.values) {
      if (bucket.count == 0) continue;
      candidates.add(_QuantizedColor(
        rgb: ColorRgb(
          (bucket.rSum / bucket.count).round(),
          (bucket.gSum / bucket.count).round(),
          (bucket.bSum / bucket.count).round(),
        ),
        count: bucket.count,
      ));
    }

    // 按像素数降序
    candidates.sort((a, b) => b.count.compareTo(a.count));

    // 合并相似颜色
    candidates = _mergeSimilarColors(candidates, config);

    // 阈值过滤 + Lab 转换
    return _colorsToDominant(candidates, totalPixels, config);
  }
}

/// 直方图桶（可变状态，仅供 HistogramStrategy 内部使用）
class _HistogramBucket {
  int count = 0;
  int rSum = 0;
  int gSum = 0;
  int bSum = 0;
}

// =====================================================================
// 策略 3: K-means 聚类
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
      // 采样点不足，回退到直方图方案
      return _fallback(image, totalPixels, config);
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

  /// 采样点不足时的回退
  List<DominantColor> _fallback(
      img.Image image, int totalPixels, ColorExtractionConfig config) {
    final strat = HistogramStrategy();
    return strat.extractFromImage(image, config: config, totalPixels: totalPixels);
  }
}

/// K-means 内部点类型（double 精度）
class _KMeansPoint {
  double r, g, b;
  _KMeansPoint(this.r, this.g, this.b);
}

// =====================================================================
// 策略 4: Mean Shift（简化版均值漂移）
//
// 从采样像素中选取种子点，迭代漂移到密度极大值（mode），
// 合并相近的 mode，按每个 mode 覆盖的像素数排序。
//
// 优点：不需要预设聚类数 K，自动发现颜色模式
// 适合：有明显主色调的图片，自然聚类
//
// 注意：这是简化版，对大数据集做了采样 + 种子点修剪，
// 且仅在颜色空间（非空间坐标）上运行。
// =====================================================================

class MeanShiftStrategy extends ColorExtractionStrategy {
  @override
  String get name => '均值漂移';

  @override
  String get description => 'Mean Shift 自动发现颜色模式，无需预设聚类数量';

  @override
  List<DominantColor> extractFromImage(
    img.Image image, {
    required ColorExtractionConfig config,
    required int totalPixels,
  }) {
    final radius = config.kernelRadius.clamp(5.0, 80.0);
    final maxIter = config.maxIterations.clamp(5, 50);
    final convergenceEpsilon = 0.5;

    // ---- 1. 采样像素 ----
    final samples = _samplePixels(image, config.sampleRate);
    if (samples.isEmpty) return [];

    // ---- 2. 选取种子点（均匀子采样） ----
    final maxSeeds = 200;
    final seedStep = max(1, samples.length ~/ maxSeeds);
    final seeds = <_KMeansPoint>[];
    for (int i = 0; i < samples.length; i += seedStep) {
      seeds.add(samples[i]);
    }

    // ---- 3. 对每个种子跑 Mean Shift ----
    final modes = <_KMeansPoint>[];

    for (final seed in seeds) {
      var center = _KMeansPoint(seed.r, seed.g, seed.b);

      for (int iter = 0; iter < maxIter; iter++) {
        // 找出 kernel 半径内的所有采样点
        var sumR = 0.0;
        var sumG = 0.0;
        var sumB = 0.0;
        var count = 0;

        for (final pt in samples) {
          final dr = pt.r - center.r;
          final dg = pt.g - center.g;
          final db = pt.b - center.b;
          if (dr * dr + dg * dg + db * db <= radius * radius) {
            sumR += pt.r;
            sumG += pt.g;
            sumB += pt.b;
            count++;
          }
        }

        if (count == 0) break; // 没有邻居，跳过

        final newCenter = _KMeansPoint(
          sumR / count,
          sumG / count,
          sumB / count,
        );

        final shift = _distSq(center, newCenter);
        center = newCenter;
        if (shift < convergenceEpsilon) break;
      }

      // 检查是否跟已有 mode 重复（合并相近 mode）
      bool merged = false;
      for (int i = 0; i < modes.length; i++) {
        if (_distSq(modes[i], center) < radius * radius * 0.25) {
          // 合并到已有的 mode（取平均）
          final w = modes.length; // 已有的权重
          modes[i] = _KMeansPoint(
            (modes[i].r * w + center.r) / (w + 1),
            (modes[i].g * w + center.g) / (w + 1),
            (modes[i].b * w + center.b) / (w + 1),
          );
          merged = true;
          break;
        }
      }
      if (!merged) {
        modes.add(center);
      }
    }

    // ---- 4. 分配像素到最近的 mode ----
    final modeCounts = List.filled(modes.length, 0);
    for (final pt in samples) {
      int bestIdx = 0;
      double bestDist = _distSq(pt, modes[0]);
      for (int k = 1; k < modes.length; k++) {
        final d = _distSq(pt, modes[k]);
        if (d < bestDist) {
          bestDist = d;
          bestIdx = k;
        }
      }
      modeCounts[bestIdx]++;
    }

    // ---- 5. 构建结果 ----
    final sampleRatio = samples.length / totalPixels;
    var quantizedColors = <_QuantizedColor>[];
    for (int k = 0; k < modes.length; k++) {
      if (modeCounts[k] == 0) continue;
      quantizedColors.add(_QuantizedColor(
        rgb: ColorRgb(
          modes[k].r.round().clamp(0, 255),
          modes[k].g.round().clamp(0, 255),
          modes[k].b.round().clamp(0, 255),
        ),
        count: (modeCounts[k] / sampleRatio).round(),
      ));
    }

    quantizedColors.sort((a, b) => b.count.compareTo(a.count));
    quantizedColors = _mergeSimilarColors(quantizedColors, config);
    return _colorsToDominant(quantizedColors, totalPixels, config);
  }

  double _distSq(_KMeansPoint a, _KMeansPoint b) {
    final dr = a.r - b.r;
    final dg = a.g - b.g;
    final db = a.b - b.b;
    return dr * dr + dg * dg + db * db;
  }
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
