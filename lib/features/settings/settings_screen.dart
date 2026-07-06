import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../services/config_exporter.dart';
import '../../services/s3_config.dart';
import '../../core/image/color_extraction_config.dart';
import '../../core/llm/config.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _versionTapCount = 0;

  void _onVersionTap() {
    _versionTapCount++;
    if (_versionTapCount >= 3) {
      _versionTapCount = 0;
      _showDebugMenu();
    }
    // 3 秒内不继续点击则重置计数
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _versionTapCount = 0);
    });
  }

  void _showDebugMenu() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          appBar: AppBar(title: const Text('调试菜单')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.bar_chart),
                  title: const Text('用户统计'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('user-stats'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: const Text('AI 配置'),
                  subtitle: const Text('标签与描述生成模型设置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('llm-settings'),
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('颜色提取算法'),
                  subtitle: const Text('配色参数配置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showColorExtractionPage,
                ),
              ),
              Consumer(
                builder: (_, ref, __) {
                  final count = ref.watch(logServiceProvider).logs.length;
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.article_outlined),
                      title: const Text('运行日志'),
                      trailing: const Icon(Icons.chevron_right),
                      subtitle: Text('共 $count 条'),
                      onTap: () => context.pushNamed('logs'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showColorExtractionPage() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog.fullscreen(
        child: Scaffold(
          appBar: AppBar(
            title: const Text('颜色提取算法配置'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [_ColorExtractionCard()],
          ),
        ),
      ),
    );
  }

  Future<void> _onExportConfig(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    try {
      final s3Config = ref.read(s3ConfigProvider).valueOrNull ?? const S3Config();
      final llmConfig = ref.read(llmConfigProvider);
      final localLlmConfig = ref.read(localLlmConfigProvider);
      final colorConfig = ref.read(colorExtractionConfigProvider);
      final themeMode = ref.read(themeModeProvider).name;
      final locale = ref.read(localeProvider)?.toString();
      final ocrEnabled = ref.read(ocrEnabledProvider);
      final llmEnabled = ref.read(llmEnabledProvider);
      final llmMode = ref.read(llmModeProvider).name;

      final jsonContent = await ConfigExporter.exportConfig(
        s3Config: s3Config,
        llmConfig: llmConfig,
        localLlmConfig: localLlmConfig,
        colorExtractionConfig: colorConfig,
        themeMode: themeMode,
        locale: locale,
        ocrEnabled: ocrEnabled,
        llmEnabled: llmEnabled,
        llmMode: llmMode,
      );

      if (!mounted) return;

      // 让用户选择导出方式
      final choice = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.exportConfig),
          content: const Text('选择导出方式'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'file'),
              child: const Text('保存为文件'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'share'),
              child: const Text('分享'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
      if (choice == null || !mounted) return;

      if (choice == 'file') {
        final path = await ConfigExporter.exportToFile(jsonContent);
        if (path != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${s.configExported}: $path')),
          );
        }
      } else if (choice == 'share') {
        await ConfigExporter.exportViaShare(jsonContent);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    }
  }

  Future<void> _onImportConfig(BuildContext context, WidgetRef ref) async {
    final s = S.of(context);
    try {
      final payload = await ConfigExporter.importFromFile();
      if (payload == null || !mounted) return;

      final errors = await ConfigExporter.applyConfig(
        payload: payload,
        saveS3Config: (config) async {
          await ref.read(s3ConfigProvider.notifier).save(config);
        },
        updateLlmConfig: (config) {
          ref.read(llmConfigProvider.notifier).update(config);
        },
        updateLocalLlmConfig: (config) {
          ref.read(localLlmConfigProvider.notifier).update(config);
        },
        updateColorExtraction: (config) {
          ref.read(colorExtractionConfigProvider.notifier).update(config);
        },
        setThemeMode: (mode) {
          ref.read(themeModeProvider.notifier).set(ThemeMode.values.byName(mode));
        },
        setLocale: (locale) {
          if (locale != null) {
            final parts = locale.split('_');
            ref.read(localeProvider.notifier)
                .set(Locale(parts[0], parts.length > 1 ? parts[1] : null));
          } else {
            ref.read(localeProvider.notifier).set(null);
          }
        },
        setOcrEnabled: (value) {
          ref.read(ocrEnabledProvider.notifier).setEnabled(value);
        },
        setLlmEnabled: (value) {
          ref.read(llmEnabledProvider.notifier).setEnabled(value);
        },
        setLlmMode: (mode) {
          ref.read(llmModeProvider.notifier).setMode(LlmMode.values.byName(mode));
        },
      );

      if (!mounted) return;

      if (errors.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.configImportSuccess)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.configImportFailed(
                errors.values.join('; '))),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.configImportFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ocrEnabled = ref.watch(ocrEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).settings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 外观
          Text(S.of(context).appearance, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(S.of(context).themeMode),
              subtitle: Text(
                switch (ref.watch(themeModeProvider)) {
                  ThemeMode.light => S.of(context).themeLight,
                  ThemeMode.dark => S.of(context).themeDark,
                  _ => S.of(context).themeSystem,
                },
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemePicker(context, ref),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.language),
              title: Text(S.of(context).language),
              subtitle: Text(
                ref.watch(localeProvider) == null
                    ? S.of(context).languageSystem
                    : ref.watch(localeProvider)!.languageCode == 'zh'
                        ? S.of(context).languageChinese
                        : S.of(context).languageEnglish,
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showLocalePicker(context, ref),
            ),
          ),

          const SizedBox(height: 24),

          // 分析
          Text(S.of(context).analysis, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: SwitchListTile(
              title: Text(S.of(context).ocrTextRecognition),
              subtitle: Text(S.of(context).ocrDescription),
              value: ocrEnabled,
              onChanged: (value) {
                ref.read(ocrEnabledProvider.notifier).setEnabled(value);
                ref.read(analysisSchedulerProvider).setOcrEnabled(value);
              },
              secondary: const Icon(Icons.text_fields),
            ),
          ),
          const SizedBox(height: 24),

          const SizedBox(height: 24),

          // 同步
          Text(S.of(context).sync, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          _S3ConfigCard(),

          const SizedBox(height: 24),

          // 存储
          Text(S.of(context).storage, style: theme.textTheme.titleSmall),
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
                      title: Text(S.of(context).storageSpace),
                      subtitle: Text(usedStr),
                    );
                  },
),
                 ListTile(
                   leading: const Icon(Icons.image),
                   title: Text(S.of(context).imageCount,
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

          const SizedBox(height: 24),

          // 配置导入导出
          Text(S.of(context).config, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(S.of(context).exportConfig),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _onExportConfig(context, ref),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Card(
                  child: ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(S.of(context).importConfig),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _onImportConfig(context, ref),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // 关于
          Text(S.of(context).about, style: theme.textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('MemeManager'),
              subtitle: Text('v1.0.0'),
              onTap: _onVersionTap,
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
        title: Text(S.of(context).s3CloudSync),
        subtitle: Text(
          isConfigured
              ? '${config.endpoint}/${config.bucket}'
              : S.of(context).notConfigured,
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
          ColorExtractionMethod.neuralQuantizer => S.of(context).methodNeuralQuantizer,
          ColorExtractionMethod.histogram => S.of(context).methodHistogram,
          ColorExtractionMethod.kmeans => S.of(context).methodKmeans,
          ColorExtractionMethod.meanShift => S.of(context).methodMeanShift,
        };

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
                // ---- 算法选择 ----
                Row(
                  children: [
                    Text(S.of(context).algorithm, style: theme.textTheme.bodyMedium),
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

  List<Widget> _buildMethodSpecificControls(
    BuildContext context,
    WidgetRef ref,
    ColorExtractionConfig config,
    ThemeData theme,
  ) {
    switch (config.method) {
      case ColorExtractionMethod.neuralQuantizer:
        return [
          _rowLabel(S.of(context).initialColorCount, '${config.initialColorCount}', theme),
          const SizedBox(height: 4),
          _dropdownControl(config.initialColorCount, [8, 16, 32, 64],
              (v) => config.copyWith(initialColorCount: v), ref),
          const SizedBox(height: 8),
        ];

      case ColorExtractionMethod.histogram:
        return [
          _rowLabel(S.of(context).rgbBins, S.of(context).rgbBinsDetail(config.histogramBins, config.histogramBins * config.histogramBins * config.histogramBins), theme),
          const SizedBox(height: 4),
          _dropdownControl(config.histogramBins, [4, 6, 8, 10, 12, 16],
              (v) => config.copyWith(histogramBins: v), ref),
          const SizedBox(height: 8),
        ];

      case ColorExtractionMethod.kmeans:
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

      case ColorExtractionMethod.meanShift:
        return [
          _rowLabel(S.of(context).kernelRadius, '${config.kernelRadius.toStringAsFixed(0)}', theme),
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
          Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(S.of(context).themeMode, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          RadioListTile<ThemeMode>(
            title: Text(S.of(context).themeLight),
            subtitle: Text(S.of(context).lightThemeSubtitle),
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
            title: Text(S.of(context).themeDark),
            subtitle: Text(S.of(context).darkThemeSubtitle),
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
            title: Text(S.of(context).themeSystem),
            subtitle: Text(S.of(context).systemThemeSubtitle),
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

void _showLocalePicker(BuildContext context, WidgetRef ref) {
  final current = ref.read(localeProvider);
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 8),
            child: Text(S.of(context).language, style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          RadioListTile<Locale?>(
            title: Text(S.of(context).languageSystem),
            secondary: const Icon(Icons.settings),
            value: null,
            groupValue: current,
            onChanged: (v) {
              ref.read(localeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<Locale?>(
            title: Text(S.of(context).languageChinese),
            secondary: const Icon(Icons.translate),
            value: const Locale('zh'),
            groupValue: current,
            onChanged: (v) {
              ref.read(localeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          RadioListTile<Locale?>(
            title: Text(S.of(context).languageEnglish),
            secondary: const Icon(Icons.language),
            value: const Locale('en'),
            groupValue: current,
            onChanged: (v) {
              ref.read(localeProvider.notifier).set(v);
              Navigator.pop(ctx);
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}
