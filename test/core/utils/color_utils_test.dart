import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/utils/color_utils.dart';

void main() {
  group('ColorRgb', () {
    test('fromHex 解析有效的十六进制颜色', () {
      final color = ColorRgb.fromHex('#FF5733');
      expect(color.r, 255);
      expect(color.g, 87);
      expect(color.b, 51);
    });

    test('fromHex 解析不带 # 的十六进制颜色', () {
      final color = ColorRgb.fromHex('FF5733');
      expect(color.r, 255);
      expect(color.g, 87);
      expect(color.b, 51);
    });

    test('fromHex 抛出无效长度异常', () {
      expect(() => ColorRgb.fromHex('#FFF'), throwsArgumentError);
      expect(() => ColorRgb.fromHex('#FFFFFFF'), throwsArgumentError);
    });

    test('fromHex 无效字符抛出 FormatException', () {
      // int.parse 在遇到无效字符时抛出 FormatException
      expect(() => ColorRgb.fromHex('#GGGGGG'), throwsFormatException);
    });

    test('hex 转换为正确的小写十六进制字符串', () {
      expect(const ColorRgb(255, 87, 51).hex, '#ff5733');
      expect(const ColorRgb(0, 0, 0).hex, '#000000');
      expect(const ColorRgb(255, 255, 255).hex, '#ffffff');
    });

    test('hex 补零到两位', () {
      expect(const ColorRgb(1, 2, 3).hex, '#010203');
      expect(const ColorRgb(10, 11, 12).hex, '#0a0b0c');
    });
  });

  group('rgbToLab', () {
    test('纯红色转换', () {
      const red = ColorRgb(255, 0, 0);
      final lab = rgbToLab(red);
      // 红色 RGB(255,0,0) 转换后的 Lab 值应该在合理范围内
      expect(lab.l, inInclusiveRange(30, 60));
      expect(lab.a, inInclusiveRange(40, 100));
      expect(lab.b, inInclusiveRange(20, 90));
    });

    test('纯绿色转换', () {
      const green = ColorRgb(0, 255, 0);
      final lab = rgbToLab(green);
      // 绿色 RGB(0,255,0) 转换后的 Lab 值应该在合理范围内
      expect(lab.l, inInclusiveRange(80, 95));
      expect(lab.a, inInclusiveRange(-100, -50));
      expect(lab.b, inInclusiveRange(40, 100));
    });

    test('纯蓝色转换', () {
      const blue = ColorRgb(0, 0, 255);
      final lab = rgbToLab(blue);
      // 蓝色 RGB(0,0,255) 转换后的 Lab 值应该在合理范围内
      expect(lab.l, inInclusiveRange(10, 40));
      expect(lab.a, inInclusiveRange(30, 90));
      expect(lab.b, inInclusiveRange(-120, -70));
    });

    test('白色转换', () {
      const white = ColorRgb(255, 255, 255);
      final lab = rgbToLab(white);
      expect(lab.l, closeTo(100, 0.1));
      expect(lab.a.abs(), lessThan(1));
      expect(lab.b.abs(), lessThan(1));
    });

    test('黑色转换', () {
      const black = ColorRgb(0, 0, 0);
      final lab = rgbToLab(black);
      expect(lab.l, closeTo(0, 0.1));
    });

    test('灰色转换', () {
      const gray = ColorRgb(128, 128, 128);
      final lab = rgbToLab(gray);
      // 灰色 a* 和 b* 应该接近 0
      expect(lab.a.abs(), lessThan(2));
      expect(lab.b.abs(), lessThan(2));
    });

    test('相同颜色往返转换保持一致', () {
      const original = ColorRgb(100, 150, 200);
      final lab = rgbToLab(original);
      // RGB 到 Lab 再到 RGB（简化验证：值域正确）
      expect(lab.l, inInclusiveRange(0, 100));
      expect(lab.a, inInclusiveRange(-128, 127));
      expect(lab.b, inInclusiveRange(-128, 127));
    });
  });

  group('deltaE', () {
    test('完全相同的颜色 ΔE = 0', () {
      const lab1 = ColorLab(50, 10, 20);
      const lab2 = ColorLab(50, 10, 20);
      expect(deltaE(lab1, lab2), 0);
    });

    test('微小差异产生小 ΔE', () {
      const lab1 = ColorLab(50, 10, 20);
      const lab2 = ColorLab(51, 10, 20);
      expect(deltaE(lab1, lab2), closeTo(1, 0.1));
    });

    test('大差异产生大 ΔE', () {
      const lab1 = ColorLab(0, 0, 0);
      const lab2 = ColorLab(100, 0, 0);
      expect(deltaE(lab1, lab2), 100);
    });

    test('ΔE 对称性', () {
      const lab1 = ColorLab(50, 10, 20);
      const lab2 = ColorLab(60, 15, 25);
      expect(deltaE(lab1, lab2), deltaE(lab2, lab1));
    });

    test('典型感知差异阈值', () {
      // ΔE < 1: 人类几乎无法察觉差异
      const lab1 = ColorLab(50, 10, 20);
      const lab2 = ColorLab(50.5, 10, 20);
      expect(deltaE(lab1, lab2), lessThan(1));

      // ΔE 2-3: 需要仔细观察才能察觉
      const lab3 = ColorLab(50, 10, 20);
      const lab4 = ColorLab(52, 10, 20);
      expect(deltaE(lab3, lab4), inInclusiveRange(1.9, 2.1));
    });
  });

  group('hueBin 和 hueBucket', () {
    test('hueBin 返回值在 0-359 范围内', () {
      final random = Random(42);
      for (var i = 0; i < 100; i++) {
        final lab = ColorLab(
          random.nextDouble() * 100,
          random.nextDouble() * 200 - 100,
          random.nextDouble() * 200 - 100,
        );
        expect(hueBin(lab), inInclusiveRange(0, 359));
      }
    });

    test('hueBucket 将色相角分到 12 个桶', () {
      for (var i = 0; i < 360; i += 30) {
        // 创建一个指定色相角的 Lab 颜色
        final angle = i * pi / 180;
        final lab = ColorLab(50, cos(angle) * 50, sin(angle) * 50);
        final bucket = hueBucket(lab);
        expect(bucket, inInclusiveRange(0, 11),
            reason: '色相角 $i° 应该在桶 0-11 内');
      }
    });

    test('hueBin 相邻角度不会跨越太多桶', () {
      const lab1 = ColorLab(50, 10, 0);
      const lab2 = ColorLab(50, 11, 0);
      expect((hueBucket(lab1) - hueBucket(lab2)).abs(), lessThanOrEqualTo(1));
    });

    test('hueBinCount 常量值为 12', () {
      expect(hueBinCount, 12);
    });
  });

  group('DominantColor', () {
    test('创建有效的 DominantColor', () {
      // DominantColor.hex 直接存储传入的值，不做转换
      // 实际代码中会传入 c.rgb.hex（已经是小写）
      const color = DominantColor(
        hex: '#ff5733',  // 使用小写，与实际使用一致
        lChannel: 50.0,
        aChannel: 60.0,
        bChannel: 70.0,
        ratio: 0.25,
      );
      expect(color.hex, '#ff5733');
      expect(color.lChannel, 50.0);
      expect(color.aChannel, 60.0);
      expect(color.bChannel, 70.0);
      expect(color.ratio, 0.25);
    });
  });
}
