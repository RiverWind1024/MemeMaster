import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/ocr/ocr_service.dart';
import '../../services/config_exporter.dart';
import '../../services/log_service.dart';
import '../../services/opencl_diagnostic.dart';
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
  PackageInfo? _packageInfo;
  int _versionTapCount = 0;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) setState(() => _packageInfo = info);
  }

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
                  leading: const Icon(Icons.palette_outlined),
                  title: const Text('颜色提取算法'),
                  subtitle: const Text('配色参数配置'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _showColorExtractionPage,
                ),
              ),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.auto_awesome),
                  title: Text(S.of(context).aiConfig),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.pushNamed('ai-config'),
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
              Card(
                child: ListTile(
                  leading: const Icon(Icons.medical_services_outlined),
                  title: const Text('GPU 加速诊断'),
                  subtitle: const Text('检测 OpenCL（libOpenCL.so）和 Vulkan（libvulkan.so）支持'),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () => _runOpenCLDiagnostic(ctx, ref),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _runOpenCLDiagnostic(BuildContext context, WidgetRef ref) {
    // 使用 logServiceProvider 提供的单例，确保日志写入同一个实例和文件
    final log = ref.read(logServiceProvider);
    log.info('Settings', '用户触发 GPU 诊断（OpenCL + Vulkan）');

    // 立即显示一个 SnackBar 反馈
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('诊断已开始，结果会写入运行日志（OpenCLDiag 标签，含 OpenCL + Vulkan）'),
        duration: Duration(seconds: 2),
      ),
    );

    // 异步运行诊断（不阻塞 UI）
    () async {
      try {
        await OpenCLDiagnostic.runAll(log);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('诊断完成，请到"运行日志"查看结果'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        log.error('Settings', 'GPU 诊断失败: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('诊断失败: $e')),
          );
        }
      }
    }();
  }

  void _startReindex(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(reindexStateProvider.notifier);
    notifier.startReindex();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(S.of(context).reindexStarted),
        duration: const Duration(seconds: 2),
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
              onChanged: (value) => _onOcrToggle(value, ref, context),
              secondary: const Icon(Icons.text_fields),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.auto_awesome),
              title: Text(S.of(context).aiTagsDescription),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.pushNamed('llm-settings'),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.refresh),
              title: Text(S.of(context).reindexMemes),
              subtitle: Text(S.of(context).reindexDescription),
              onTap: () => _startReindex(context, ref),
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
              title: Text('MemeMaster'),
              subtitle: Text('v${_packageInfo?.version ?? "1.0.0"}'),
              onTap: _onVersionTap,
            ),
          ),
          const SizedBox(height: 8),
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

Future<void> _onOcrToggle(bool value, WidgetRef ref, BuildContext ctx) async {
  final log = ref.read(logServiceProvider);

  if (!value) {
    // 关闭 OCR：直接禁用
    log.info('OCR', '用户关闭 OCR 开关');
    ref.read(ocrEnabledProvider.notifier).setEnabled(false);
    ref.read(analysisSchedulerProvider).setOcrEnabled(false);
    return;
  }

  // 开启 OCR：检查依赖
  log.info('OCR', '用户尝试开启 OCR 开关，平台: ${Platform.operatingSystem}');

  if (Platform.isLinux) {
    log.info('OCR', '检查 Linux Tesseract 安装状态...');
    final installed = await OcrService.linuxCheckInstalled();
    log.info('OCR', 'Linux Tesseract 安装状态: $installed');
    if (!installed) {
      log.warning('OCR', 'Linux Tesseract 未安装，显示安装对话框');
      // 显示安装对话框
      final confirmed = await showDialog<bool>(
        context: ctx,
        builder: (dialogContext) => AlertDialog(
          title: const Text('需要安装 OCR 组件'),
          content: const Text(
            'OCR 功能需要 Tesseract。\n\n是否自动安装？\n安装过程需要管理员权限。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('安装'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        log.info('OCR', '用户取消安装 Tesseract');
        return; // 用户取消
      }

      // 执行安装
      log.info('OCR', '开始自动安装 Tesseract...');
      final success = await OcrService.linuxTryInstall();
      log.info('OCR', 'Tesseract 安装结果: $success');
      if (!success) {
        log.error('OCR', 'Tesseract 自动安装失败');
        if (ctx.mounted) {
          ScaffoldMessenger.of(ctx).showSnackBar(
            const SnackBar(
              content: Text('安装失败，请检查网络连接后重试'),
            ),
          );
        }
        return;
      }
    }
  } else if (Platform.isMacOS) {
    log.info('OCR', 'macOS 使用 Apple Vision Framework，始终可用');
    // macOS: Apple Vision 是系统框架，始终可用，无需检查安装
  } else if (Platform.isWindows) {
    log.info('OCR', '检查 Windows Tesseract 安装状态...');
    final installed = await OcrService.windowsCheckInstalled();
    log.info('OCR', 'Windows Tesseract 安装状态: $installed');
    if (!installed) {
      log.warning('OCR', 'Windows Tesseract 未安装，提示用户手动安装');
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(
            content: Text('Tesseract 未安装。请从 https://github.com/UB-Mannheim/tesseract/wiki 下载安装'),
            duration: Duration(seconds: 5),
          ),
        );
      }
      return;
    }
  }

  // 启用 OCR
  log.info('OCR', 'OCR 检查通过，启用 OCR 功能');
  ref.read(ocrEnabledProvider.notifier).setEnabled(true);
  ref.read(analysisSchedulerProvider).setOcrEnabled(true);
}
