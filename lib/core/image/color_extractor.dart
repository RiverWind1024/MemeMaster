import 'dart:io';

import 'package:image/image.dart' as img;

import '../utils/color_utils.dart';
import 'color_extraction_config.dart';
import 'color_extraction_strategies.dart';

/// 颜色提取器 — 默认使用 K-means 算法
class ColorExtractor {
  final ColorExtractionConfig defaultConfig;

  const ColorExtractor({this.defaultConfig = const ColorExtractionConfig()});

  static final _strategies = <ColorExtractionMethod, ColorExtractionStrategy>{
    ColorExtractionMethod.kmeans: KMeansStrategy(),
  };

  /// 提取图片的主色调
  ///
  /// [config] 可覆盖默认配置；不传则使用构造时的 [defaultConfig]。
  Future<List<DominantColor>> extract(String imagePath,
      {ColorExtractionConfig? config}) async {
    final cfg = config ?? defaultConfig;
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('Image file not found', imagePath);
    }

    final bytes = await file.readAsBytes();
    final image = img.decodeImage(bytes);
    if (image == null) {
      throw FormatException('Unable to decode image: $imagePath');
    }

    return extractFromImage(image, config: cfg);
  }

  /// 从已解码的 [img.Image] 中提取主色调
  List<DominantColor> extractFromImage(img.Image image,
      {required ColorExtractionConfig config}) {
    final totalPixels = image.width * image.height;
    if (totalPixels == 0) return [];

    final strategy = _strategies[config.method] ?? _strategies[ColorExtractionMethod.kmeans]!;
    return strategy.extractFromImage(
      image,
      config: config,
      totalPixels: totalPixels,
    );
  }
}
