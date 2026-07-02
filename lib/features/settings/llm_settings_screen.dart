import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../gallery/gallery_provider.dart';

class LlmSettingsScreen extends ConsumerWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(llmModeProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final localConfig = ref.watch(localLlmConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 标签与描述')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模式选择
          Text('分析模式', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SegmentedButton<LlmMode>(
                segments: const [
                  ButtonSegment(value: LlmMode.off, label: Text('关闭'), icon: Icon(Icons.cancel_outlined, size: 18)),
                  ButtonSegment(value: LlmMode.remote, label: Text('远程 API'), icon: Icon(Icons.cloud_outlined, size: 18)),
                  ButtonSegment(value: LlmMode.local, label: Text('本地模型'), icon: Icon(Icons.phone_android_outlined, size: 18)),
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
              LlmMode.off => 'AI 标签功能已关闭，不会分析图片内容。',
              LlmMode.remote => '通过远程 API 分析图片，需联网且消耗 API 额度。',
              LlmMode.local => '在设备端本地运行模型，无需联网，需下载模型文件。',
            },
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),

          const SizedBox(height: 24),

          // 远程模式配置
          if (mode == LlmMode.remote) ...[
            Text('远程 API 配置', style: theme.textTheme.titleMedium),
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
                      decoration: const InputDecoration(
                        labelText: '供应商',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: LlmProviderType.openai,
                          child: Text('OpenAI 兼容'),
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
                      decoration: const InputDecoration(
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
                      decoration: const InputDecoration(
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
                      decoration: const InputDecoration(
                        labelText: '模型',
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
              '需要支持多模态视觉的模型，如 GPT-4o、GPT-4o-mini、Qwen2-VL 等。',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],

          // 本地模式配置
          if (mode == LlmMode.local) ...[
            Text('本地模型', style: theme.textTheme.titleMedium),
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
                        subtitle: Text('已加载', style: theme.textTheme.bodySmall),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => context.push('/settings/llm/model-manager'),
                              child: const Text('管理'),
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
                        title: const Text('GPU 加速'),
                        value: localConfig.useGpu,
                        onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                          localConfig.copyWith(useGpu: v),
                        ),
                        secondary: const Icon(Icons.memory),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.tune),
                        title: const Text('上下文长度'),
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
                      const Text('暂无已下载的模型'),
                      const SizedBox(height: 4),
                      Text(
                        '将 GGUF 模型文件放入应用存储目录的 models/ 文件夹',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => context.push('/settings/llm/model-manager'),
                        icon: const Icon(Icons.open_in_new),
                        label: const Text('下载推荐模型'),
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
}
