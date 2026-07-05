import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../../core/llm/local_service.dart';
import '../../core/llm/models.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class LlmSettingsScreen extends ConsumerStatefulWidget {
  const LlmSettingsScreen({super.key});

  @override
  ConsumerState<LlmSettingsScreen> createState() => _LlmSettingsScreenState();
}

class _LlmSettingsScreenState extends ConsumerState<LlmSettingsScreen> {
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
                          return DropdownMenuItem(
                            value: d.id,
                            child: Text('${d.id} ($sizeMB MB)'),
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
                        subtitle: ref.watch(localLlmLoadingProvider)
                            ? Text('正在加载…', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange))
                            : ref.watch(localLlmLoadedProvider)
                                ? Text(S.of(context).loaded, style: theme.textTheme.bodySmall)
                                : Text('已配置，点击下方「加载模型」按钮', style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange)),
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
                      if (ref.watch(localLlmLoadingProvider))
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: LinearProgressIndicator(),
                        ),
                      if (!ref.watch(localLlmLoadedProvider) && !ref.watch(localLlmLoadingProvider))
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: OutlinedButton.icon(
                            onPressed: () => _loadModel(),
                            icon: const Icon(Icons.play_arrow, size: 18),
                            label: const Text('加载模型'),
                          ),
                        ),
                      const Divider(),
                      SwitchListTile(
                        title: Text(S.of(context).gpuAcceleration),
                        value: localConfig.useGpu,
                        onChanged: (v) {
                          ref.read(localLlmConfigProvider.notifier).update(
                            localConfig.copyWith(useGpu: v),
                          );
                          // GPU 设置修改后也需要重新加载模型才能生效
                          if (ref.read(localLlmLoadedProvider)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('GPU 设置已修改，请点击「加载模型」重新加载以生效'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        secondary: const Icon(Icons.memory),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: Text(S.of(context).contextLength),
                        trailing: DropdownButton<int>(
                          value: localConfig.contextSize,
                          underline: const SizedBox(),
                          items: [512, 1024, 2048, 4096].map((n) {
                            return DropdownMenuItem(value: n, child: Text('$n'));
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              ref.read(localLlmConfigProvider.notifier).update(
                                localConfig.copyWith(contextSize: v),
                              );
                              // 如果模型已加载，提示用户需要重新加载才能生效
                              if (ref.read(localLlmLoadedProvider)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('上下文长度已修改，请点击「加载模型」重新加载以生效'),
                                    duration: Duration(seconds: 3),
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.science_outlined),
                        title: Text('测试推理'),
                        subtitle: Text('将发送 "Who are you?" 验证模型加载和推理是否正常',
                            style: theme.textTheme.bodySmall),
                        trailing: FilledButton.tonalIcon(
                          onPressed: () => _runTestInference(),
                          icon: const Icon(Icons.play_arrow, size: 18),
                          label: Text('测试'),
                        ),
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
    debugPrint('[LoadModel] 开始加载模型: ${config.modelPath}');
    debugPrint('[LoadModel] 模型文件存在: ${File(config.modelPath!).existsSync()}');
    debugPrint('[LoadModel] 模型文件大小: ${File(config.modelPath!).lengthSync()} bytes');

    // 等一帧让进度条先渲染出来
    await Future.delayed(const Duration(milliseconds: 50));

    try {
      // 获取实际的 LocalLlmService 实例并将模型加载到其中
      // 与 runTestInference 不同：后者创建独立实例加载后立即释放，
      // 这里直接让分析调度器使用的服务持有模型句柄
      final service = ref.read(llmServiceProvider);
      if (service is LocalLlmService) {
        debugPrint('[LoadModel] 调用 service.ensureLoaded...');
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

  Future<void> _runTestInference() async {
    final config = ref.read(localLlmConfigProvider);
    if (config.modelPath == null) return;

    debugPrint('[TestInference] 开始测试推理, modelPath=${config.modelPath}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // 等一帧让 loading dialog 先渲染出来，再执行同步 FFI
    await Future.delayed(const Duration(milliseconds: 100));

    try {
      final result = await runTestInferenceAsync(
        modelPath: config.modelPath!,
        mmprojPath: config.mmprojPath,
        threads: config.effectiveThreads,
        contextSize: config.contextSize,
        prompt: 'Who are you?',
        maxTokens: 32,
        temperature: 0.7,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('推理测试失败'),
            content: const Text('模型加载返回空指针，请检查模型文件是否损坏。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      } else {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('推理测试成功'),
            content: Text('模型返回: "$result"'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('[TestInference] 测试推理异常: $e');
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('推理测试失败'),
          content: Text('错误: $e\n\n请检查模型文件是否正确。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('确定'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _pickLocalModel() async {
    // 选择 GGUF 模型文件
    final modelFile = await openFile(
      acceptedTypeGroups: [
        XTypeGroup(
          label: S.of(context).ggufModelFile,
          extensions: ['gguf'],
        ),
      ],
    );
    if (modelFile == null || !mounted) return;

    // 校验文件后缀（Linux 上 file_selector 的 extensions 过滤可被用户绕过）
    if (!modelFile.path.toLowerCase().endsWith('.gguf')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).invalidGgufFileDetail(
            modelFile.path.split('/').last,
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
        content: Text(
          S.of(context).mmprojHint,
        ),
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
      final mmprojFile = await openFile(
        acceptedTypeGroups: [
          XTypeGroup(
            label: S.of(context).ggufProjectionFile,
            extensions: ['gguf'],
          ),
        ],
      );
      if (mmprojFile != null) {
        // 同样校验 mmproj 文件后缀
        if (!mmprojFile.path.toLowerCase().endsWith('.gguf')) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(S.of(context).invalidGgufFileDetail(
                mmprojFile.path.split('/').last,
              )),
            ),
          );
        } else {
          mmprojPath = mmprojFile.path;
        }
      }
    }

    if (!mounted) return;
    ref.read(localLlmConfigProvider.notifier).update(
      LocalLlmConfig(
        modelPath: modelFile.path,
        mmprojPath: mmprojPath,
      ),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).modelFileLoaded)),
    );
  }
}
