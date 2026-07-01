import 'package:flutter/material.dart';

import '../../core/utils/color_utils.dart';

/// 预设色板颜色
class PresetColor {
  final String label;
  final int value;
  final ColorRgb rgb;

  const PresetColor({
    required this.label,
    required this.value,
    required this.rgb,
  });
}

/// 预设色板
const kPresetColors = [
  PresetColor(label: '红', value: 0xFFE53935, rgb: ColorRgb(229, 57, 53)),
  PresetColor(label: '深橙', value: 0xFFFF7043, rgb: ColorRgb(255, 112, 67)),
  PresetColor(label: '橙', value: 0xFFFF9800, rgb: ColorRgb(255, 152, 0)),
  PresetColor(label: '琥珀', value: 0xFFFFC107, rgb: ColorRgb(255, 193, 7)),
  PresetColor(label: '黄', value: 0xFFFFEB3B, rgb: ColorRgb(255, 235, 59)),
  PresetColor(label: '柠绿', value: 0xFFCDDC39, rgb: ColorRgb(205, 220, 57)),
  PresetColor(label: '浅绿', value: 0xFF8BC34A, rgb: ColorRgb(139, 195, 74)),
  PresetColor(label: '绿', value: 0xFF4CAF50, rgb: ColorRgb(76, 175, 80)),
  PresetColor(label: '青', value: 0xFF26C6DA, rgb: ColorRgb(38, 198, 218)),
  PresetColor(label: '浅蓝', value: 0xFF03A9F4, rgb: ColorRgb(3, 169, 244)),
  PresetColor(label: '蓝', value: 0xFF2196F3, rgb: ColorRgb(33, 150, 243)),
  PresetColor(label: '靛蓝', value: 0xFF3F51B5, rgb: ColorRgb(63, 81, 181)),
  PresetColor(label: '深紫', value: 0xFF673AB7, rgb: ColorRgb(103, 58, 183)),
  PresetColor(label: '紫', value: 0xFF9C27B0, rgb: ColorRgb(156, 39, 176)),
  PresetColor(label: '粉', value: 0xFFE91E63, rgb: ColorRgb(233, 30, 99)),
  PresetColor(label: '棕', value: 0xFF795548, rgb: ColorRgb(121, 85, 72)),
  PresetColor(label: '灰', value: 0xFF9E9E9E, rgb: ColorRgb(158, 158, 158)),
  PresetColor(label: '蓝灰', value: 0xFF607D8B, rgb: ColorRgb(96, 125, 139)),
  PresetColor(label: '黑', value: 0xFF212121, rgb: ColorRgb(33, 33, 33)),
  PresetColor(label: '白', value: 0xFFFFFFFF, rgb: ColorRgb(255, 255, 255)),
];

/// 颜色选择面板 — 预设色板 + 自定义入口
class ColorPickerPalette extends StatelessWidget {
  final List<int> selectedValues;
  final ValueChanged<int> onToggle;
  final VoidCallback onCustom;

  const ColorPickerPalette({
    super.key,
    required this.selectedValues,
    required this.onToggle,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...kPresetColors.map((c) => _ColorChip(
              color: Color(c.value),
              label: c.label,
              selected: selectedValues.contains(c.value),
              onTap: () => onToggle(c.value),
            )),
        // 自定义颜色入口
        _CustomColorButton(onTap: onCustom),
      ],
    );
  }
}

class _ColorChip extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ColorChip({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWhite = color == Colors.white;
    final luminance = color.computeLuminance();
    final borderColor = isWhite || luminance > 0.8
        ? Colors.grey.shade300
        : Colors.transparent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? colorScheme.primary : borderColor,
            width: selected ? 3 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: selected
            ? Icon(Icons.check, size: 18, color: isWhite ? Colors.black : Colors.white)
            : null,
      ),
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CustomColorButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
            width: 2,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Icon(
          Icons.add,
          size: 20,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
