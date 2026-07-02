import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
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
                    if (localConfig.modelPath != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.check_circle, color: Colors.green),
                        title: Text(
                          localConfig.modelPath!.split('/').last,
                          style: theme.textTheme.bodyMedium,
                        ),
                        subtitle: Text(S.of(context).loaded, style: theme.textTheme.bodySmall),
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
                              },
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      SwitchListTile(
                        title: Text(S.of(context).gpuAcceleration),
                        value: localConfig.useGpu,
                        onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                          localConfig.copyWith(useGpu: v),
                        ),
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
                            }
                          },
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

    // 可选：选择 mmproj 文件
    final wantMmproj = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).loadMultimodalProjection),
        content: const Text(
          '如果你的模型支持图片输入（多模态），建议同时选择 mmproj 投影文件。\n\n'
          '不需要请点「跳过」',
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
        mmprojPath = mmprojFile.path;
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
