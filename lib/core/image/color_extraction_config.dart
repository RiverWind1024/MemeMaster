/// 颜色提取算法类型
enum ColorExtractionMethod {
  neuralQuantizer,
  histogram,
  kmeans,
  meanShift,
}

/// 颜色提取算法的可配置参数
///
/// 不同算法会用到不同的参数子集：
/// - [neuralQuantizer]：initialColorCount / minRatio / maxResultColors / mergeThreshold
/// - [histogram]：histogramBins / minRatio / maxResultColors / mergeThreshold
/// - [kmeans]：initialColorCount / minRatio / maxResultColors / mergeThreshold / sampleRate / maxIterations
/// - [meanShift]：kernelRadius / minRatio / maxResultColors / mergeThreshold / sampleRate / maxIterations
class ColorExtractionConfig {
  /// 使用的算法
  final ColorExtractionMethod method;

  /// NeuralQuantizer / K-means 的初始聚类数（调色板大小）
  /// 越大保留的细节越多，但计算量增大。推荐 16-64。
  final int initialColorCount;

  /// 最小像素占比阈值（0.0 - 1.0）
  /// 低于此比例的颜色不被视为主色调。默认 5%。
  final double minRatio;

  /// 最大返回主色调数量
  final int maxResultColors;

  /// 相似颜色合并阈值（CIE Lab ΔE）
  /// 色差小于此值的相邻颜色会被合并。默认 12。
  final double mergeThreshold;

  /// 直方图/聚类等算法的 RGB 分桶数（每通道）
  /// 8 → 8×8×8 = 512 桶, 16 → 4096 桶
  final int histogramBins;

  /// K-means / Mean Shift 的像素采样率（0.0 - 1.0）
  /// 1.0 = 全像素, 0.1 = 10% 采样
  final double sampleRate;

  /// Mean Shift 的核半径（RGB Euclidean 距离）
  final double kernelRadius;

  /// K-means / Mean Shift 的最大迭代次数
  final int maxIterations;

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'initialColorCount': initialColorCount,
        'minRatio': minRatio,
        'maxResultColors': maxResultColors,
        'mergeThreshold': mergeThreshold,
        'histogramBins': histogramBins,
        'sampleRate': sampleRate,
        'kernelRadius': kernelRadius,
        'maxIterations': maxIterations,
      };

  factory ColorExtractionConfig.fromJson(Map<String, dynamic> json) =>
      ColorExtractionConfig(
        method: ColorExtractionMethod.values.byName(json['method'] as String),
        initialColorCount: json['initialColorCount'] as int,
        minRatio: (json['minRatio'] as num).toDouble(),
        maxResultColors: json['maxResultColors'] as int,
        mergeThreshold: (json['mergeThreshold'] as num).toDouble(),
        histogramBins: json['histogramBins'] as int,
        sampleRate: (json['sampleRate'] as num).toDouble(),
        kernelRadius: (json['kernelRadius'] as num).toDouble(),
        maxIterations: json['maxIterations'] as int,
      );

  const ColorExtractionConfig({
    this.method = ColorExtractionMethod.kmeans,
    this.initialColorCount = 32,
    this.minRatio = 0.03,
    this.maxResultColors = 8,
    this.mergeThreshold = 12.0,
    this.histogramBins = 8,
    this.sampleRate = 0.2,
    this.kernelRadius = 30.0,
    this.maxIterations = 20,
  });

  ColorExtractionConfig copyWith({
    ColorExtractionMethod? method,
    int? initialColorCount,
    double? minRatio,
    int? maxResultColors,
    double? mergeThreshold,
    int? histogramBins,
    double? sampleRate,
    double? kernelRadius,
    int? maxIterations,
  }) {
    return ColorExtractionConfig(
      method: method ?? this.method,
      initialColorCount: initialColorCount ?? this.initialColorCount,
      minRatio: minRatio ?? this.minRatio,
      maxResultColors: maxResultColors ?? this.maxResultColors,
      mergeThreshold: mergeThreshold ?? this.mergeThreshold,
      histogramBins: histogramBins ?? this.histogramBins,
      sampleRate: sampleRate ?? this.sampleRate,
      kernelRadius: kernelRadius ?? this.kernelRadius,
      maxIterations: maxIterations ?? this.maxIterations,
    );
  }
}
