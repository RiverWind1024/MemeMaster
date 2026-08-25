import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/image/color_extraction_config.dart';
import '../../l10n/app_localizations.dart';
import '../gallery/gallery_provider.dart';

/// 颜色提取算法参数配置页面（与设置其他选项保持一致的 push 页面导航）
class ColorExtractionScreen extends ConsumerWidget {
  const ColorExtractionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('颜色提取算法配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [_ColorExtractionCard()],
      ),
    );
  }
}

/// 颜色提取参数配置卡片
class _ColorExtractionCard extends ConsumerWidget {
  const _ColorExtractionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(colorExtractionConfigProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context).colorExtraction, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- K-means 特定参数 ----
                ..._buildKMeansControls(context, ref, config, theme),

                const Divider(height: 16),

                // ---- 通用参数 ----

                // 最大返回颜色数
                Row(
                  children: [
                    Text(S.of(context).maxDominantColors,
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    DropdownButton<int>(
                      value: config.maxResultColors,
                      underline: const SizedBox(),
                      items: List.generate(10, (i) => i + 3).map((n) {
                        return DropdownMenuItem(value: n, child: Text(S.of(context).colorCount(n)));
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref
                              .read(colorExtractionConfigProvider.notifier)
                              .update(config.copyWith(maxResultColors: v));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 最小占比阈值
                Row(
                  children: [
                    Text(S.of(context).minRatio,
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('${(config.minRatio * 100).round()}%',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        )),
                  ],
                ),
                Slider(
                  value: config.minRatio,
                  min: 0.01,
                  max: 0.50,
                  divisions: 49,
                  label: '${(config.minRatio * 100).round()}%',
                  onChanged: (v) => ref
                      .read(colorExtractionConfigProvider.notifier)
                      .update(config.copyWith(minRatio: v)),
                ),
                const SizedBox(height: 8),

                // 颜色合并阈值
                Row(
                  children: [
                    Text(S.of(context).colorMergeThreshold,
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Text('${config.mergeThreshold.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                        )),
                  ],
                ),
                Slider(
                  value: config.mergeThreshold,
                  min: 1,
                  max: 30,
                  divisions: 29,
                  label: '${config.mergeThreshold.round()}',
                  onChanged: (v) => ref
                      .read(colorExtractionConfigProvider.notifier)
                      .update(config.copyWith(mergeThreshold: v)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildKMeansControls(
    BuildContext context,
    WidgetRef ref,
    ColorExtractionConfig config,
    ThemeData theme,
  ) {
    return [
      _rowLabel(S.of(context).initialClusterK, '${config.initialColorCount}', theme),
      const SizedBox(height: 4),
      _dropdownControl(config.initialColorCount, [8, 16, 32, 48, 64],
          (v) => config.copyWith(initialColorCount: v), ref),
      const SizedBox(height: 8),
      _rowLabel(S.of(context).pixelSampleRate, '${(config.sampleRate * 100).round()}%', theme),
      const SizedBox(height: 4),
      Slider(
        value: config.sampleRate,
        min: 0.05,
        max: 1.0,
        divisions: 19,
        label: '${(config.sampleRate * 100).round()}%',
        onChanged: (v) => ref
            .read(colorExtractionConfigProvider.notifier)
            .update(config.copyWith(sampleRate: v)),
      ),
      const SizedBox(height: 8),
      _rowLabel(S.of(context).maxIterations, '${config.maxIterations}', theme),
      const SizedBox(height: 4),
      _dropdownControl(config.maxIterations, [10, 20, 30, 50, 100],
          (v) => config.copyWith(maxIterations: v), ref),
      const SizedBox(height: 8),
    ];
  }

  Widget _rowLabel(String label, String value, ThemeData theme) {
    return Row(
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        const Spacer(),
        Text(value,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.primary)),
      ],
    );
  }

  Widget _dropdownControl<T>(
    T currentValue,
    List<T> options,
    ColorExtractionConfig Function(T) copyFn,
    WidgetRef ref,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        DropdownButton<T>(
          value: currentValue,
          underline: const SizedBox(),
          items: options.map((v) {
            return DropdownMenuItem(value: v, child: Text('$v'));
          }).toList(),
          onChanged: (v) {
            if (v != null) {
              ref.read(colorExtractionConfigProvider.notifier).update(
                  copyFn(v));
            }
          },
        ),
      ],
    );
  }
}
