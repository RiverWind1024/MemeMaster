import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/s3_config.dart';
import '../../core/image/color_extraction_config.dart';
import '../gallery/gallery_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final ocrEnabled = ref.watch(ocrEnabledProvider);
    final llmEnabled = ref.watch(llmEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观
          Text('外观', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('主题模式'),
              subtitle: Text(
                switch (ref.watch(themeModeProvider)) {
                  ThemeMode.light => '浅色',
                  ThemeMode.dark => '深色',
                  _ => '跟随系统',
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemePicker(context, ref),
            ),
          ),

          const SizedBox(height: 24),

          // 分析
          Text('分析', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('OCR 文字识别'),
              subtitle: const Text('导入图片时自动提取图片中的文字作为标签'),
              value: ocrEnabled,
              onChanged: (value) {
                ref.read(ocrEnabledProvider.notifier).setEnabled(value);
                ref.read(analysisSchedulerProvider).setOcrEnabled(value);
              },
              secondary: const Icon(Icons.text_fields),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: const Text('AI 标签与描述'),
              // TODO(Phase 2): LLM 直接分析图片识别内容生成标签（当前基于 OCR 文本）
              subtitle: const Text('根据图片内容自动生成标签和描述'),
              value: llmEnabled,
              onChanged: (value) {
                ref.read(llmEnabledProvider.notifier).setEnabled(value);
                ref.read(analysisSchedulerProvider).setLlmEnabled(value);
              },
              secondary: const Icon(Icons.auto_awesome),
            ),
          ),

          const SizedBox(height: 24),

          // 颜色提取
          _ColorExtractionCard(),

          const SizedBox(height: 24),

          // 同步
          Text('同步', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _S3ConfigCard(),

          const SizedBox(height: 24),

          // 存储
          Text('存储', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Column(
              children: [
                FutureBuilder<int>(
                  future: ref.read(fileStorageServiceProvider).storageUsed(),
                  builder: (context, snapshot) {
                    final used = snapshot.data ?? 0;
                    final usedStr = used < 1024 * 1024
                        ? '${(used / 1024).toStringAsFixed(1)} KB'
                        : '${(used / (1024 * 1024)).toStringAsFixed(1)} MB';
                    return ListTile(
                      leading: const Icon(Icons.storage),
                      title: const Text('存储空间'),
                      subtitle: Text(usedStr),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.image),
                  title: Text('图片数量',
                      style: theme.textTheme.bodyMedium),
                  trailing: ref.watch(memeCountProvider).when(
                    loading: () => const SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (_, __) =>
                        Text('?', style: theme.textTheme.bodyMedium),
                    data: (count) =>
                        Text('$count', style: theme.textTheme.bodyMedium),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // 调试
          Text('调试', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('运行日志'),
              subtitle: Text(
                '共 ${ref.watch(logServiceProvider).logs.length} 条',
                style: theme.textTheme.bodySmall,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('logs'),
            ),
          ),

          const SizedBox(height: 24),

          // 关于
          Text('关于', style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('MemeManager'),
              subtitle: Text('v1.0.0'),
            ),
          ),
        ],
      ),
    );
  }
}

class _S3ConfigCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(s3ConfigProvider).valueOrNull ?? const S3Config();
    final isConfigured = config.isValid;
    final theme = Theme.of(context);

    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_sync),
        title: const Text('S3 云同步'),
        subtitle: Text(
          isConfigured
              ? '${config.endpoint}/${config.bucket}'
              : '未配置',
          style: theme.textTheme.bodySmall,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.pushNamed('s3-sync'),
      ),
    );
  }
}

/// 颜色提取参数配置卡片
class _ColorExtractionCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(colorExtractionConfigProvider);
    final theme = Theme.of(context);

    String methodLabel(ColorExtractionMethod m) => switch (m) {
          ColorExtractionMethod.neuralQuantizer => '神经网络量化',
          ColorExtractionMethod.histogram => '直方图分桶',
          ColorExtractionMethod.kmeans => 'K-means 聚类',
          ColorExtractionMethod.meanShift => '均值漂移',
        };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('颜色提取', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ---- 算法选择 ----
                Row(
                  children: [
                    Text('算法', style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    DropdownButton<ColorExtractionMethod>(
                      value: config.method,
                      underline: const SizedBox(),
                      items: ColorExtractionMethod.values.map((m) {
                        return DropdownMenuItem(
                          value: m,
                          child: Text(methodLabel(m)),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) {
                          ref
                .read(colorExtractionConfigProvider.notifier)
                .update(config.copyWith(method: v));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // ---- 算法特定参数 ----
                ..._buildMethodSpecificControls(context, ref, config, theme),

                const Divider(height: 16),

                // ---- 通用参数 ----

                // 最大返回颜色数
                Row(
                  children: [
                    Text('最大主色调数',
                        style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    DropdownButton<int>(
                      value: config.maxResultColors,
                      underline: const SizedBox(),
                      items: List.generate(10, (i) => i + 3).map((n) {
                        return DropdownMenuItem(value: n, child: Text('$n 色'));
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
                    Text('最小占比',
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
                    Text('颜色合并阈值',
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

  List<Widget> _buildMethodSpecificControls(
    BuildContext context,
    WidgetRef ref,
    ColorExtractionConfig config,
    ThemeData theme,
  ) {
    switch (config.method) {
      case ColorExtractionMethod.neuralQuantizer:
        return [
          _rowLabel('初始颜色数量', '${config.initialColorCount}', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.initialColorCount, [8, 16, 32, 64],
              (v) => config.copyWith(initialColorCount: v), ref),
          const SizedBox(height: 8),
        ];

      case ColorExtractionMethod.histogram:
        return [
          _rowLabel('RGB 分桶数', '${config.histogramBins}³ = ${config.histogramBins * config.histogramBins * config.histogramBins} 桶', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.histogramBins, [4, 6, 8, 10, 12, 16],
              (v) => config.copyWith(histogramBins: v), ref),
          const SizedBox(height: 8),
        ];

      case ColorExtractionMethod.kmeans:
        return [
          _rowLabel('初始聚类数 (K)', '${config.initialColorCount}', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.initialColorCount, [8, 16, 32, 48, 64],
              (v) => config.copyWith(initialColorCount: v), ref),
          const SizedBox(height: 8),
          _rowLabel('像素采样率', '${(config.sampleRate * 100).round()}%', theme),
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
          _rowLabel('最大迭代次数', '${config.maxIterations}', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.maxIterations, [10, 20, 30, 50, 100],
              (v) => config.copyWith(maxIterations: v), ref),
          const SizedBox(height: 8),
        ];

      case ColorExtractionMethod.meanShift:
        return [
          _rowLabel('核半径', '${config.kernelRadius.toStringAsFixed(0)}', theme),
          const SizedBox(height: 4),
          Slider(
            value: config.kernelRadius,
            min: 5,
            max: 80,
            divisions: 15,
            label: '${config.kernelRadius.round()}',
                  onChanged: (v) => ref
                      .read(colorExtractionConfigProvider.notifier)
                      .update(config.copyWith(kernelRadius: v)),
          ),
          const SizedBox(height: 8),
          _rowLabel('像素采样率', '${(config.sampleRate * 100).round()}%', theme),
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
          _rowLabel('最大迭代次数', '${config.maxIterations}', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.maxIterations, [10, 20, 30, 50, 100],
              (v) => config.copyWith(maxIterations: v), ref),
          const SizedBox(height: 8),
        ];
    }
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

void _showThemePicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(themeModeProvider);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text('主题模式', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('浅色'),
            subtitle: const Text('始终使用浅色主题'),
            secondary: const Icon(Icons.light_mode),
            value: ThemeMode.light,
            groupValue: current,
            onChanged: (v) {
              if (v == null) return;
              ref.read(themeModeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('深色'),
            subtitle: const Text('始终使用深色主题'),
            secondary: const Icon(Icons.dark_mode),
            value: ThemeMode.dark,
            groupValue: current,
            onChanged: (v) {
              if (v == null) return;
              ref.read(themeModeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('跟随系统'),
            subtitle: const Text('跟随系统设置自动切换'),
            secondary: const Icon(Icons.settings),
            value: ThemeMode.system,
            groupValue: current,
            onChanged: (v) {
              if (v == null) return;
              ref.read(themeModeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
