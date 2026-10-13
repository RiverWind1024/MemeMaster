import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/theme/app_theme.dart';

void main() {
  group('主题 tertiary 色（S3 进度条下载阶段依赖）', () {
    test('浅色主题 tertiary 必须与 primary 明显不同', () {
      final scheme = buildLightTheme().colorScheme;
      expect(
        scheme.tertiary,
        isNot(equals(scheme.primary)),
        reason: 'ColorScheme 未定义 tertiary 时会回退到 secondary；'
            '而本主题 secondary 与 primary 同色，导致进度条上传/下载同色。',
      );
    });

    test('深色主题 tertiary 必须与 primary 明显不同', () {
      final scheme = buildDarkTheme().colorScheme;
      expect(scheme.tertiary, isNot(equals(scheme.primary)));
    });
  });

  group('容器色槽位（避免回退到纯色）', () {
    test('errorContainer 与 error 不同（防止红图标叠红底不可见）', () {
      for (final scheme in [
        buildLightTheme().colorScheme,
        buildDarkTheme().colorScheme,
      ]) {
        expect(
          scheme.errorContainer,
          isNot(equals(scheme.error)),
          reason: '未定义 errorContainer 会回退到 error（纯红），'
              '而错误卡片里的图标正是 error 色，会叠在同色背景上看不见。',
        );
      }
    });

    test('secondaryContainer 与 secondary 不同（防止 chip 纯色底 + 低对比字）', () {
      for (final scheme in [
        buildLightTheme().colorScheme,
        buildDarkTheme().colorScheme,
      ]) {
        expect(scheme.secondaryContainer, isNot(equals(scheme.secondary)));
      }
    });
  });
}
