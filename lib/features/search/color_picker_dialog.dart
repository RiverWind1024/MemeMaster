import 'package:flutter/material.dart';

import '../../core/utils/color_utils.dart';
import '../../l10n/app_localizations.dart';

/// HSV 颜色选择器对话框
class ColorPickerDialog extends StatefulWidget {
  final ColorRgb? initialColor;

  const ColorPickerDialog({super.key, this.initialColor});

  /// 显示对话框，返回选中的颜色
  static Future<ColorRgb?> show(BuildContext context, {ColorRgb? initial}) {
    return showDialog<ColorRgb>(
      context: context,
      builder: (_) => ColorPickerDialog(initialColor: initial),
    );
  }

  @override
  State<ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<ColorPickerDialog> {
  late double _hue;
  late double _saturation;
  late double _value;

  @override
  void initState() {
    super.initState();
    if (widget.initialColor != null) {
      final c = widget.initialColor!;
      final hsv = HSVColor.fromColor(Color.fromARGB(255, c.r, c.g, c.b));
      _hue = hsv.hue;
      _saturation = hsv.saturation;
      _value = hsv.value;
    } else {
      _hue = 0;
      _saturation = 0.8;
      _value = 0.9;
    }
  }

  Color get _currentColor =>
      HSVColor.fromAHSV(1, _hue, _saturation, _value).toColor();

  ColorRgb get _currentRgb {
    final cv = _currentColor.value;
    return ColorRgb(
      (cv >> 16) & 0xFF,
      (cv >> 8) & 0xFF,
      cv & 0xFF,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: Text(S.of(context).customColor),
      content: SizedBox(
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 2D 饱和度×明度区域
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 260,
                height: 180,
                child: _SaturationValuePicker(
                  hue: _hue,
                  saturation: _saturation,
                  value: _value,
                  onChanged: (s, v) {
                    setState(() {
                      _saturation = s;
                      _value = v;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 色相滑块
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 260,
                height: 24,
                child: _HuePicker(
                  hue: _hue,
                  onChanged: (h) => setState(() => _hue = h),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 预览
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _currentColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _currentRgb.hex.toUpperCase(),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      'H: ${_hue.round()}° S: ${(_saturation * 100).round()}% V: ${(_value * 100).round()}%',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(S.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_currentRgb),
          child: Text(S.of(context).confirm),
        ),
      ],
    );
  }
}

/// 2D 饱和度×明度选择区域
class _SaturationValuePicker extends StatefulWidget {
  final double hue;
  final double saturation;
  final double value;
  final void Function(double saturation, double value) onChanged;

  const _SaturationValuePicker({
    required this.hue,
    required this.saturation,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SaturationValuePicker> createState() => _SaturationValuePickerState();
}

class _SaturationValuePickerState extends State<_SaturationValuePicker> {
  final GlobalKey _key = GlobalKey();

  Offset? _position;

  Offset _getPosition(double saturation, double value) {
    return Offset(saturation * 260, (1 - value) * 180);
  }

  void _updateFromPosition(Offset localPosition) {
    final clampedX = localPosition.dx.clamp(0.0, 260.0).toDouble();
    final clampedY = localPosition.dy.clamp(0.0, 180.0).toDouble();
    final s = clampedX / 260;
    final v = 1 - clampedY / 180;
    setState(() {
      _position = Offset(clampedX, clampedY);
    });
    widget.onChanged(s.clamp(0.0, 1.0).toDouble(), v.clamp(0.0, 1.0).toDouble());
  }

  @override
  void initState() {
    super.initState();
    _position = _getPosition(widget.saturation, widget.value);
  }

  @override
  void didUpdateWidget(_SaturationValuePicker old) {
    super.didUpdateWidget(old);
    if (old.saturation != widget.saturation || old.value != widget.value) {
      _position = _getPosition(widget.saturation, widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      key: _key,
      builder: (context, constraints) {
        return GestureDetector(
          onPanDown: (d) => _updateFromPosition(d.localPosition),
          onPanUpdate: (d) => _updateFromPosition(d.localPosition),
          child: CustomPaint(
            painter: _SaturationValuePainter(hue: widget.hue),
            child: Stack(
              children: [
                Positioned.fill(child: Container()),
                if (_position != null)
                  Positioned(
                    left: _position!.dx - 8,
                    top: _position!.dy - 8,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: HSVColor.fromAHSV(1, widget.hue, widget.saturation, widget.value).toColor(),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  final double hue;

  _SaturationValuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 绘制渐变背景
    // 从左到右：饱和度从 0 到 1
    // 从上到下：明度从 1 到 0
    final baseColor = HSVColor.fromAHSV(1, hue, 1, 1).toColor();

    // 白色→纯色（从左到右）
    final horizontalGradient = LinearGradient(
      colors: [Colors.white, baseColor],
    );
    final paint = Paint()
      ..shader = horizontalGradient.createShader(rect);
    canvas.drawRect(rect, paint);

    // 透明→黑色（从上到下）
    final verticalGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black],
    );
    final paint2 = Paint()
      ..shader = verticalGradient.createShader(rect);
    canvas.drawRect(rect, paint2);
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter old) =>
      old.hue != hue;
}

/// 水平色相条选择器
class _HuePicker extends StatelessWidget {
  final double hue;
  final ValueChanged<double> onChanged;

  const _HuePicker({required this.hue, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final knobX = (hue / 360) * width;

        return GestureDetector(
          onPanDown: (d) => onChanged((d.localPosition.dx / width).clamp(0, 1) * 360),
          onPanUpdate: (d) => onChanged((d.localPosition.dx / width).clamp(0, 1) * 360),
          child: Stack(
            children: [
              // 色相渐变条
              CustomPaint(
                painter: _HueBarPainter(),
                size: Size(width, 24),
              ),
              // 滑块
              Positioned(
                left: knobX - 8,
                top: 0,
                child: Container(
                  width: 16,
                  height: 24,
                  decoration: BoxDecoration(
                    color: HSVColor.fromAHSV(1, hue, 1, 1).toColor(),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HueBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final gradient = LinearGradient(
      colors: [
        Color(0xFFFF0000), // 0°
        Color(0xFFFFFF00), // 60°
        Color(0xFF00FF00), // 120°
        Color(0xFF00FFFF), // 180°
        Color(0xFF0000FF), // 240°
        Color(0xFFFF00FF), // 300°
        Color(0xFFFF0000), // 360°
      ],
    );
    final paint = Paint()
      ..shader = gradient.createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(8)),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
