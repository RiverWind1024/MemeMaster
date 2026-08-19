import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/theme/app_theme.dart';

void main() {
  group('buildLightTheme', () {
    final theme = buildLightTheme();
    final cs = theme.colorScheme;

    test('强调色为 indigo #4F46E5', () {
      expect(cs.primary.toARGB32(), const Color(0xFF4F46E5).toARGB32());
    });

    test('主背景 surface 为白色 #FFFFFF', () {
      expect(cs.surface.toARGB32(), const Color(0xFFFFFFFF).toARGB32());
    });

    test('主文字 onSurface 为 #111827', () {
      expect(cs.onSurface.toARGB32(), const Color(0xFF111827).toARGB32());
    });
  });

  group('buildDarkTheme', () {
    final theme = buildDarkTheme();
    final cs = theme.colorScheme;

    test('主背景 surface 为深色 #121215', () {
      expect(cs.surface.toARGB32(), const Color(0xFF121215).toARGB32());
    });

    test('强调色为 indigo #6366F1', () {
      expect(cs.primary.toARGB32(), const Color(0xFF6366F1).toARGB32());
    });

    test('主文字 onSurface 为 #F4F4F5', () {
      expect(cs.onSurface.toARGB32(), const Color(0xFFF4F4F5).toARGB32());
    });
  });
}