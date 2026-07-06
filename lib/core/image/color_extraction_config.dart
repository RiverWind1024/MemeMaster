/// 颜色提取算法类型
enum ColorExtractionMethod {
  kmeans,
}

/// 颜色提取算法的可配置参数
///
/// 仅保留 K-means 算法及其参数。
class ColorExtractionConfig {
  /// 使用的算法（固定为 kmeans）
  final ColorExtractionMethod method;

  /// K-means 的初始聚类数（调色板大小）
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

  /// K-means 的像素采样率（0.0 - 1.0）
  /// 1.0 = 全像素, 0.1 = 10% 采样
  final double sampleRate;

  /// K-means 的最大迭代次数
  final int maxIterations;

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'initialColorCount': initialColorCount,
        'minRatio': minRatio,
        'maxResultColors': maxResultColors,
        'mergeThreshold': mergeThreshold,
        'sampleRate': sampleRate,
        'maxIterations': maxIterations,
      };

  factory ColorExtractionConfig.fromJson(Map<String, dynamic> json) {
    // 兼容旧版：已移除的算法默认切到 kmeans
    final method = () {
      try {
        final raw = json['method'] as String?;
        if (raw == null) return ColorExtractionMethod.kmeans;
        return ColorExtractionMethod.values.byName(raw);
      } catch (_) {
        return ColorExtractionMethod.kmeans;
      }
    }();
    return ColorExtractionConfig(
      method: method,
      initialColorCount: json['initialColorCount'] as int? ?? 32,
      minRatio: (json['minRatio'] as num?)?.toDouble() ?? 0.03,
      maxResultColors: json['maxResultColors'] as int? ?? 8,
      mergeThreshold: (json['mergeThreshold'] as num?)?.toDouble() ?? 12.0,
      sampleRate: (json['sampleRate'] as num?)?.toDouble() ?? 0.2,
      maxIterations: json['maxIterations'] as int? ?? 20,
    );
  }

  const ColorExtractionConfig({
    this.method = ColorExtractionMethod.kmeans,
    this.initialColorCount = 32,
    this.minRatio = 0.03,
    this.maxResultColors = 8,
    this.mergeThreshold = 12.0,
    this.sampleRate = 0.2,
    this.maxIterations = 20,
  });

  ColorExtractionConfig copyWith({
    ColorExtractionMethod? method,
    int? initialColorCount,
    double? minRatio,
    int? maxResultColors,
    double? mergeThreshold,
    double? sampleRate,
    int? maxIterations,
  }) {
    return ColorExtractionConfig(
      method: method ?? this.method,
      initialColorCount: initialColorCount ?? this.initialColorCount,
      minRatio: minRatio ?? this.minRatio,
      maxResultColors: maxResultColors ?? this.maxResultColors,
      mergeThreshold: mergeThreshold ?? this.mergeThreshold,
      sampleRate: sampleRate ?? this.sampleRate,
      maxIterations: maxIterations ?? this.maxIterations,
    );
  }
}
