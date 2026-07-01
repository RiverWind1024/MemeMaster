import 'package:flutter_test/flutter_test.dart';
import 'package:meme_helper/core/utils/color_utils.dart';

void main() {
  group('ColorRgb', () {
    test('constructor stores values', () {
      const color = ColorRgb(255, 128, 0);
      expect(color.r, 255);
      expect(color.g, 128);
      expect(color.b, 0);
    });

    group('fromHex', () {
      test('parses hex with # prefix', () {
        final color = ColorRgb.fromHex('#ff8000');
        expect(color.r, 255);
        expect(color.g, 128);
        expect(color.b, 0);
      });

      test('parses hex without # prefix', () {
        final color = ColorRgb.fromHex('ff8000');
        expect(color.r, 255);
        expect(color.g, 128);
        expect(color.b, 0);
      });

      test('parses black', () {
        final color = ColorRgb.fromHex('#000000');
        expect(color.r, 0);
        expect(color.g, 0);
        expect(color.b, 0);
      });

      test('parses white', () {
        final color = ColorRgb.fromHex('#ffffff');
        expect(color.r, 255);
        expect(color.g, 255);
        expect(color.b, 255);
      });

      test('throws on invalid hex length', () {
        expect(
          () => ColorRgb.fromHex('#fff'),
          throwsArgumentError,
        );
      });

      test('throws on empty string', () {
        expect(
          () => ColorRgb.fromHex(''),
          throwsArgumentError,
        );
      });
    });

    group('hex getter', () {
      test('produces correct format', () {
        const color = ColorRgb(255, 128, 0);
        expect(color.hex, '#ff8000');
      });

      test('pads single hex digits', () {
        const color = ColorRgb(1, 2, 3);
        expect(color.hex, '#010203');
      });
    });
  });

  group('rgbToLab', () {
    test('black maps to L≈0', () {
      final lab = rgbToLab(const ColorRgb(0, 0, 0));
      expect(lab.l, closeTo(0, 1));
    });

    test('white maps to L≈100', () {
      final lab = rgbToLab(const ColorRgb(255, 255, 255));
      expect(lab.l, closeTo(100, 1));
    });

    test('red has positive a*', () {
      final lab = rgbToLab(const ColorRgb(255, 0, 0));
      expect(lab.a, greaterThan(0));
    });
  });

  group('deltaE', () {
    test('identical colors have 0 deltaE', () {
      final a = ColorLab(50, 0, 0);
      final b = ColorLab(50, 0, 0);
      expect(deltaE(a, b), closeTo(0, 0.001));
    });

    test('different colors have positive deltaE', () {
      final a = ColorLab(50, 50, 0);
      final b = ColorLab(20, -50, 30);
      expect(deltaE(a, b), greaterThan(0));
    });
  });
}
