import 'dart:ui';

import 'package:flutter/material.dart';

/// TREK 风格毛玻璃容器：BackdropFilter blur + 半透明背景 + 高光描边 + 阴影
class GlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final double borderRadius;
  final bool showBorder;
  final EdgeInsetsGeometry padding;
  final Color? background;

  const GlassContainer({
    super.key,
    required this.child,
    this.blur = 22,
    this.borderRadius = 14,
    this.showBorder = true,
    this.padding = EdgeInsets.zero,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = background ??
        (isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.7));

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(borderRadius),
            border: showBorder
                ? Border.all(color: Colors.white.withValues(alpha: 0.1))
                : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}