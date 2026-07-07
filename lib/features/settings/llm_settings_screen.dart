import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../../core/llm/local_service.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
  String _loadingLogs = '';
  final ScrollController _logScrollController = ScrollController();

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(llmModeProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final localConfig = ref.watch(localLlmConfigProvider);
    final enabledModels = ref.watch(enabledModelsProvider);
    final enabledDownloaded = ref.read(modelManagerProvider).getDownloadedModels()
        .where((d) => enabledModels.contains(d.id))
        .toList();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).aiTagsAndDescription)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模式选择
          Text(S.of(context).analysisMode, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<LlmMode>(
                segments: [
                  ButtonSegment(value: LlmMode.off, label: Text(S.of(context).modeOff), icon: Icon(Icons.cancel_outlined, size: 18)),
                  ButtonSegment(value: LlmMode.remote, label: Text(S.of(context).modeRemoteApi), icon: Icon(Icons.cloud_outlined, size: 18)),
                  ButtonSegment(value: LlmMode.local, label: Text(S.of(context).modeLocalModel), icon: Icon(Icons.phone_android_outlined, size: 18)),
                ],
                selected: {mode},
                onSelectionChanged: (selected) {
                  ref.read(llmModeProvider.notifier).setMode(selected.first);
                },
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            switch (mode) {
              LlmMode.off => S.of(context).modeOffDescription,
              LlmMode.remote => S.of(context).modeRemoteDescription,
              LlmMode.local => S.of(context).modeLocalDescription,
            },
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 24),

          // 分析参数配置（通用，远程和本地都可用）
          _AnalysisParamsCard(mode: mode),

          const SizedBox(height: 24),

          // 远程模式配置
          if (mode == LlmMode.remote) ...[
            Text(S.of(context).remoteApiConfig, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 供应商选择
                    DropdownButtonFormField<LlmProviderType>(
                      value: llmConfig.provider,
                      decoration: InputDecoration(
                        labelText: S.of(context).provider,
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: LlmProviderType.openai,
                          child: Text(S.of(context).openaiCompatible),
                        ),
                        DropdownMenuItem(
                          value: LlmProviderType.ollama,
                          child: Text('Ollama'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          ref.read(llmConfigProvider.notifier).update(
                            llmConfig.copyWith(provider: v),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: llmConfig.baseUrl,
                      decoration: InputDecoration(
                        labelText: 'Endpoint',
                        hintText: 'https://api.openai.com/v1',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                        llmConfig.copyWith(baseUrl: v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: llmConfig.apiKey,
                      decoration: InputDecoration(
                        labelText: 'API Key',
                        hintText: 'sk-...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                        llmConfig.copyWith(apiKey: v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: llmConfig.model,
                      decoration: InputDecoration(
                        labelText: S.of(context).model,
                        hintText: 'gpt-4o-mini',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                        llmConfig.copyWith(model: v),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).multimodalModelHint,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],

          // 本地模式配置
          if (mode == LlmMode.local) ...[
            Text(S.of(context).localModel, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // 模型选择器：从已启用的模型中选取当前使用的模型
                    if (enabledDownloaded.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        value: localConfig.modelPath != null
                            ? (enabledDownloaded.where((d) => d.modelPath == localConfig.modelPath).isNotEmpty
                                ? enabledDownloaded.firstWhere((d) => d.modelPath == localConfig.modelPath).id
                                : null)
                            : null,
                        decoration: InputDecoration(
                          labelText: '选择模型',
                          border: const OutlineInputBorder(),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        items: enabledDownloaded.map((d) {
                          final sizeMB = (d.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
                          // 截断过长的模型名称，只显示文件名部分
                          final displayName = d.filename.length > 30
                              ? '${d.filename.substring(0, 27)}...'
                              : d.filename;
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('$displayName ($sizeMB MB)'),
                          );
                        }).toList(),
                        onChanged: (v) {
                          if (v != null) {
                            final selected = enabledDownloaded.firstWhere((d) => d.id == v);
                            ref.read(localLlmConfigProvider.notifier).update(
                              LocalLlmConfig(
                                modelPath: selected.modelPath,
                                mmprojPath: selected.mmprojPath,
                              ),
                            );
                            ref.read(localLlmLoadedProvider.notifier).state = false;
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (localConfig.modelPath != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: ref.watch(localLlmLoadedProvider)
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : const Icon(Icons.info_outline, color: Colors.orange),
                        title: Text(
                          localConfig.modelPath!.split('/').last,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ref.watch(localLlmLoadingProvider)
                                ? Text('正在加载…', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange))
                                : ref.watch(localLlmLoadedProvider)
                                    ? Text(S.of(context).loaded, style: theme.textTheme.bodySmall)
                                    : Text('已配置，分析时自动加载', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange)),
                            // 显示 mmproj 状态（包括文件是否真实存在）
                            _MmprojStatusText(mmprojPath: localConfig.mmprojPath),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/settings/llm/model-manager'),
                              child: Text(S.of(context).manage),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                ref.read(localLlmConfigProvider.notifier).update(
                                  const LocalLlmConfig(),
                                );
                                ref.read(localLlmLoadedProvider.notifier).state = false;
                              },
                            ),
                          ],
                        ),
                      ),
                      if (ref.watch(localLlmLoadingProvider)) ...[
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                        // 加载日志实时显示区域
                        Container(
                          constraints: BoxConstraints(maxHeight: 200),
                          margin: EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView(
                            controller: _logScrollController,
                            padding: EdgeInsets.all(8),
                            children: [
                              if (_loadingLogs.isEmpty)
                                Text('等待日志…',
                                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey))
                              else
                                Text(_loadingLogs,
                                  style: TextStyle(fontFamily: 'monospace', fontSize: 11, height: 1.3),
                                ),
                            ],
                          ),
                        ),
                      ],
                        if (!ref.watch(localLlmLoadedProvider) && !ref.watch(localLlmLoadingProvider))
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Text(
                              '分析图片时将自动加载模型',
                              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                            ),
                          ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: Text(S.of(context).localModelConfig),
                        subtitle: Text('GPU 加速 · 上下文长度 · 高级性能',
                            style: theme.textTheme.bodySmall),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.pushNamed('local-model-config'),
                      ),
                    ] else ...[
                      const Icon(Icons.download_outlined, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(S.of(context).noDownloadedModelsHint),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context).downloadOrSelectLocal,
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => context.push('/settings/llm/model-manager'),
                            icon: const Icon(Icons.cloud_download_outlined, size: 18),
                            label: Text(S.of(context).downloadRecommended),
                          ),
                          const SizedBox(width: 12),
                          FilledButton.tonalIcon(
                            onPressed: _pickLocalModel,
                            icon: const Icon(Icons.folder_open, size: 18),
                            label: Text(S.of(context).selectLocalFile),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _loadModel() async {
    final config = ref.read(localLlmConfigProvider);
    if (config.modelPath == null) return;

    ref.read(localLlmLoadingProvider.notifier).state = true;
    setState(() => _loadingLogs = '');
    debugPrint('[LoadModel] 开始加载模型: ${config.modelPath}');
    final modelFile = File(config.modelPath!);
    final fileExists = modelFile.existsSync();
    debugPrint('[LoadModel] 模型文件存在: $fileExists');
    if (fileExists) {
      debugPrint('[LoadModel] 模型文件大小: ${modelFile.lengthSync()} bytes');
    } else {
      debugPrint('[LoadModel] 模型文件不存在，跳过长度检查');
      ref.read(localLlmLoadingProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('模型文件不存在，请检查模型路径或重新下载')),
        );
      }
      return;
    }

    // 等一帧让进度条先渲染出来
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // 获取实际的 LocalLlmService 实例并将模型加载到其中
      // 与 runTestInference 不同：后者创建独立实例加载后立即释放，
      // 这里直接让分析调度器使用的服务持有模型句柄
      final service = ref.read(llmServiceProvider);
      if (service is LocalLlmService) {
        debugPrint('[LoadModel] 调用 service.ensureLoaded...');
        service.onLoadingLog = (logLines) {
          if (mounted) {
            setState(() {
              _loadingLogs += logLines;
              // 限制日志长度，避免 OOM
              if (_loadingLogs.length > 50000) {
                _loadingLogs = _loadingLogs.substring(_loadingLogs.length - 40000);
              }
            });
            // 滚动到底部
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_logScrollController.hasClients) {
                _logScrollController.jumpTo(_logScrollController.position.maxScrollExtent);
              }
            });
          }
        };
        await service.ensureLoaded();
        ref.read(localLlmLoadedProvider.notifier).state = true;
        debugPrint('[LoadModel] 模型加载成功');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('模型加载成功')),
          );
        }
      } else {
        debugPrint('[LoadModel] 当前 LLM 模式不是本地模式');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先切换到本地模型模式')),
          );
        }
      }
    } catch (e) {
      debugPrint('[LoadModel] 模型加载失败: $e');
      ref.read(localLlmLoadedProvider.notifier).state = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('模型加载失败: $e')),
        );
      }
    } finally {
      ref.read(localLlmLoadingProvider.notifier).state = false;
    }
  }

  Future<void> _pickLocalModel() async {
    // 选择 GGUF 模型文件
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['gguf'],
    );
    if (result == null || result.files.isEmpty || !mounted) return;

    final modelPath = result.files.single.path;
    if (modelPath == null) return;

    // 双重校验：FilePicker 已按 extensions 过滤，但以防被绕过
    if (!modelPath.toLowerCase().endsWith('.gguf')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).invalidGgufFileDetail(
            modelPath.split('/').last,
          )),
        ),
      );
      return;
    }

    // 可选：选择 mmproj 文件
    final wantMmproj = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).loadMultimodalProjection),
        content: Text(S.of(context).mmprojHint),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).skip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).selectProjectionFile),
          ),
        ],
      ),
    );

    String? mmprojPath;
    if (wantMmproj == true && mounted) {
      final mmprojResult = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gguf'],
      );
      if (mmprojResult != null && mmprojResult.files.isNotEmpty) {
        final path = mmprojResult.files.single.path;
        if (path != null) {
          if (!path.toLowerCase().endsWith('.gguf')) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(S.of(context).invalidGgufFileDetail(
                  path.split('/').last,
                )),
              ),
            );
          } else {
            mmprojPath = path;
          }
        }
      }
    }

    if (!mounted) return;
    ref.read(localLlmConfigProvider.notifier).update(
      LocalLlmConfig(
        modelPath: modelPath,
        mmprojPath: mmprojPath,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).modelFileLoaded)),
    );
  }
}

/// 显示 mmproj 状态（检查文件是否真实存在）
/// 分析参数配置卡片（temperature / maxTokens / 自定义 prompt）
class _AnalysisParamsCard extends ConsumerWidget {
  final LlmMode mode;
  const _AnalysisParamsCard({required this.mode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // 根据当前模式获取对应配置
    final isRemote = mode == LlmMode.remote;
    final isLocal = mode == LlmMode.local;
    if (!isRemote && !isLocal) return const SizedBox.shrink();

    // LlmConfig 和 LocalLlmConfig 字段相同，用 dynamic 避免联合类型问题
    final dynamic config = isRemote
        ? ref.watch(llmConfigProvider)
        : ref.watch(localLlmConfigProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(S.of(context).analysisParams, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Temperature
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Temperature', style: theme.textTheme.bodyMedium),
                          Text(
                            '控制输出随机性（0=确定，1=最大随机）',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 80,
                      child: TextFormField(
                        key: ValueKey('temp_${config.temperature}'),
                        initialValue: config.temperature.toString(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (v) {
                          final t = double.tryParse(v);
                          if (t != null && t >= 0 && t <= 2) {
                            _updateConfig(ref, isRemote, config.copyWith(temperature: t));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 图片压缩开关
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(S.of(context).imageCompression),
                  subtitle: Text(
                    S.of(context).imageCompressionHint,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: config.imageCompressionEnabled,
                  onChanged: (v) => _updateConfig(
                    ref,
                    isRemote,
                    config.copyWith(imageCompressionEnabled: v),
                  ),
                ),
                const SizedBox(height: 12),
                // Max Tokens
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Max Tokens', style: theme.textTheme.bodyMedium),
                          Text(
                            '单次输出最大 token 数',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 100,
                      child: TextFormField(
                        key: ValueKey('maxtokens_${config.maxTokens}'),
                        initialValue: config.maxTokens.toString(),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        keyboardType: TextInputType.number,
                        onChanged: (v) {
                          final n = int.tryParse(v);
                          if (n != null && n > 0 && n <= 8192) {
                            _updateConfig(ref, isRemote, config.copyWith(maxTokens: n));
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                // 自定义 System Prompt
                Text('System Prompt（留空使用默认）', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '覆盖默认系统提示词模板，影响标签生成规则和质量',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('sysprompt_${config.customSystemPrompt ?? "default"}'),
                  initialValue: config.customSystemPrompt ?? '',
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '使用默认系统提示词...',
                  ),
                  maxLines: 4,
                  onChanged: (v) {
                    final trimmed = v.trim();
                    _updateConfig(
                      ref,
                      isRemote,
                      trimmed.isEmpty
                          ? config.copyWith(clearSystemPrompt: true)
                          : config.copyWith(customSystemPrompt: trimmed),
                    );
                  },
                ),
                const SizedBox(height: 12),
                // 自定义 User Prompt
                Text('User Prompt（留空使用默认）', style: theme.textTheme.bodyMedium),
                const SizedBox(height: 4),
                Text(
                  '覆盖默认用户提示词，影响分析时的引导语',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: ValueKey('userprompt_${config.customUserPrompt ?? "default"}'),
                  initialValue: config.customUserPrompt ?? '',
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: '使用默认用户提示词...',
                  ),
                  maxLines: 2,
                  onChanged: (v) {
                    final trimmed = v.trim();
                    _updateConfig(
                      ref,
                      isRemote,
                      trimmed.isEmpty
                          ? config.copyWith(clearUserPrompt: true)
                          : config.copyWith(customUserPrompt: trimmed),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _updateConfig(WidgetRef ref, bool isRemote, dynamic config) {
    if (isRemote) {
      ref.read(llmConfigProvider.notifier).update(config as LlmConfig);
    } else {
      ref.read(localLlmConfigProvider.notifier).update(config as LocalLlmConfig);
    }
  }
}

class _MmprojStatusText extends StatelessWidget {
  final String? mmprojPath;
  const _MmprojStatusText({this.mmprojPath});

  @override
  Widget build(BuildContext context) {
    if (mmprojPath == null) {
      return Text(
        '⚠️ mmproj: 未配置（无法分析图片）',
        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
      );
    }

    final file = File(mmprojPath!);
    if (!file.existsSync()) {
      return Text(
        '⚠️ mmproj 文件不存在: ${mmprojPath!.split('/').last}',
        style: TextStyle(fontSize: 12, color: Colors.red.shade700),
      );
    }

    final sizeMB = (file.lengthSync() / (1024 * 1024)).toStringAsFixed(1);
    return Text(
      '✓ mmproj: ${mmprojPath!.split('/').last} ($sizeMB MB)',
      style: TextStyle(fontSize: 12, color: Colors.green.shade700),
    );
  }
}
