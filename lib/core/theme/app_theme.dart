import 'package:flutter/material.dart';

import 'app_radius.dart';

/// 浅色主题（TREK 风格：indigo 强调色 + 浅灰表面 + 白背景）
ThemeData buildLightTheme() {
  return _buildTheme(
    const ColorScheme.light(
      primary: Color(0xFF4F46E5),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE0E7FF),
      onPrimaryContainer: Color(0xFF312E81),
      secondary: Color(0xFF4F46E5),
      onSecondary: Colors.white,
      // 未定义时会回退到 secondary（=primary 纯紫），使 chip 变纯紫底、
      // 灰字对比不足；这里给浅紫底 + 深紫字。
      secondaryContainer: Color(0xFFE0E7FF),
      onSecondaryContainer: Color(0xFF312E81),
      // tertiary 未显式定义时会回退到 secondary（=primary 同色），
      // 导致 S3 进度条上传/下载两阶段同色。这里给一个明显区分的青色。
      tertiary: Color(0xFF0891B2),
      onTertiary: Colors.white,
      // 页面背景用 off-white，卡片用纯白浮在其上，拉开层次（原先背景纯白、
      // 卡片 #F8FAFC，两者几乎同色，卡片边界看不出来）。
      surface: Color(0xFFF7F8FA),
      onSurface: Color(0xFF111827),
      onSurfaceVariant: Color(0xFF374151),
      surfaceContainerLow: Color(0xFFFFFFFF),
      surfaceContainerHigh: Color(0xFFF1F3F5),
      surfaceContainerHighest: Color(0xFFE9ECEF),
      outline: Color(0xFF6B7280),
      outlineVariant: Color(0xFFD1D5DB),
      // 未定义时会回退到 error（纯红），导致红色图标叠红底不可见；
      // 这里给浅红底 + 深红字，保证图标可见。
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF991B1B),
      error: Color(0xFFDC2626),
      onError: Colors.white,
    ),
    Brightness.light,
  );
}

/// 深色主题（TREK 风格：近黑背景 #121215 + 深灰表面）
ThemeData buildDarkTheme() {
  return _buildTheme(
    const ColorScheme.dark(
      primary: Color(0xFF6366F1),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF3730A3),
      onPrimaryContainer: Color(0xFFE0E7FF),
      secondary: Color(0xFF6366F1),
      onSecondary: Colors.white,
      // 同浅色主题：显式定义 secondary/tertiary 容器色，避免回退到纯色。
      secondaryContainer: Color(0xFF3730A3),
      onSecondaryContainer: Color(0xFFE0E7FF),
      tertiary: Color(0xFF22D3EE),
      onTertiary: Colors.black,
      surface: Color(0xFF121215),
      onSurface: Color(0xFFF4F4F5),
      onSurfaceVariant: Color(0xFFD4D4D8),
      surfaceContainerLow: Color(0xFF1A1A1E),
      surfaceContainerHigh: Color(0xFF26262B),
      surfaceContainerHighest: Color(0xFF303036),
      outline: Color(0xFFA1A1AA),
      outlineVariant: Color(0xFF3F3F46),
      // 同浅色主题：显式定义 errorContainer，避免回退到纯红。
      errorContainer: Color(0xFF7F1D1D),
      onErrorContainer: Color(0xFFFECACA),
      error: Color(0xFFEF4444),
      onError: Colors.white,
    ),
    Brightness.dark,
  );
}

ThemeData _buildTheme(ColorScheme scheme, Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final base = ThemeData(useMaterial3: true, colorScheme: scheme);

  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: base.textTheme
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface)
        .copyWith(
          titleLarge: base.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
          titleMedium: base.textTheme.titleMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
          bodySmall: base.textTheme.bodySmall?.copyWith(
            color: scheme.outline,
          ),
        ),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      elevation: 0,
      scrolledUnderElevation: 0,
      foregroundColor: scheme.onSurface,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      elevation: 0,
      height: 68,
      indicatorColor: scheme.primary.withValues(alpha: isDark ? 0.25 : 0.14),
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? IconThemeData(color: scheme.primary)
            : IconThemeData(color: scheme.onSurfaceVariant),
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: isDark ? const Color(0xF01A1A1E) : const Color(0xF2FFFFFF),
      elevation: 12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: isDark ? const Color(0xF21A1A1E) : const Color(0xF5FFFFFF),
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      modalBackgroundColor:
          isDark ? const Color(0xF21A1A1E) : const Color(0xF5FFFFFF),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    tabBarTheme: TabBarThemeData(
      indicatorColor: scheme.primary,
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurfaceVariant,
      dividerColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isDark ? const Color(0xFF1A1A1E) : const Color(0xFF111827),
      contentTextStyle:
          TextStyle(color: isDark ? const Color(0xFFF4F4F5) : Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant.withValues(alpha: 0.6),
    ),
  );
}