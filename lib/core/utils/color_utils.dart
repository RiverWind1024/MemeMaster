import 'dart:math';

/// sRGB 颜色值
class ColorRgb {
  final int r;
  final int g;
  final int b;

  const ColorRgb(this.r, this.g, this.b);

  String get hex =>
      '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';

  factory ColorRgb.fromHex(String hex) {
    final h = hex.replaceFirst('#', '');
    if (h.length != 6) throw ArgumentError('Invalid hex color: $hex');
    return ColorRgb(
      int.parse(h.substring(0, 2), radix: 16),
      int.parse(h.substring(2, 4), radix: 16),
      int.parse(h.substring(4, 6), radix: 16),
    );
  }
}

/// CIE Lab 色彩空间值（D65 标准照明体）
class ColorLab {
  final double l;
  final double a;
  final double b;

  const ColorLab(this.l, this.a, this.b);
}

/// 主色调提取结果
class DominantColor {
  final String hex;
  final double lChannel;
  final double aChannel;
  final double bChannel;
  final double ratio;

  const DominantColor({
    required this.hex,
    required this.lChannel,
    required this.aChannel,
    required this.bChannel,
    required this.ratio,
  });
}

// ---- RGB ↔ Lab 转换 ----

/// sRGB → CIE XYZ（D65）
ColorXyz _rgbToXyz(ColorRgb rgb) {
  double linearize(double c) {
    final s = c / 255.0;
    return s <= 0.04045 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = linearize(rgb.r.toDouble());
  final g = linearize(rgb.g.toDouble());
  final b = linearize(rgb.b.toDouble());

  // sRGB → XYZ（D65）
  return ColorXyz(
    0.4124564 * r + 0.3575761 * g + 0.1804375 * b,
    0.2126729 * r + 0.7151522 * g + 0.0721750 * b,
    0.0193339 * r + 0.1191920 * g + 0.9503041 * b,
  );
}

class ColorXyz {
  final double x, y, z;
  const ColorXyz(this.x, this.y, this.z);
}

/// CIE XYZ → CIE Lab（D65）
ColorLab _xyzToLab(ColorXyz xyz) {
  const refX = 0.95047;
  const refY = 1.0;
  const refZ = 1.08883;

  double f(double t) {
    return t > 0.008856 ? pow(t, 1.0 / 3.0).toDouble() : (7.787 * t + 16.0 / 116.0);
  }

  final fx = f(xyz.x / refX);
  final fy = f(xyz.y / refY);
  final fz = f(xyz.z / refZ);

  return ColorLab(
    116.0 * fy - 16.0,
    500.0 * (fx - fy),
    200.0 * (fy - fz),
  );
}

/// RGB → Lab 完整转换
ColorLab rgbToLab(ColorRgb rgb) {
  return _xyzToLab(_rgbToXyz(rgb));
}

// ---- ΔE 色差 ----

/// CIE76 ΔE 色差
double deltaE(ColorLab a, ColorLab b) {
  final dl = a.l - b.l;
  final da = a.a - b.a;
  final db = a.b - b.b;
  return sqrt(dl * dl + da * da + db * db);
}

// ---- 色相桶 ----

/// 从 Lab 计算色相角度（0-359°），用于粗筛
int hueBin(ColorLab lab) {
  final hue = atan2(lab.b, lab.a) * 180.0 / pi;
  if (hue < 0) return (hue + 360).round();
  return hue.round();
}

/// 色相桶数量（每 30° 一个桶）
const int hueBinCount = 12;

/// 色相桶编号（0-11），每 30° 一个分区
int hueBucket(ColorLab lab) {
  return (hueBin(lab) ~/ 30) % hueBinCount;
}
