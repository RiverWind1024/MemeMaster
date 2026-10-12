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
}
