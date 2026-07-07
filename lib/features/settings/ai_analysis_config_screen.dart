import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

/// AI 分析配置页面（关于页面入口）
/// 包含：temperature、maxTokens、system prompt、user prompt、图片压缩
/// 对远程 API 和本地模型都生效
class AiAnalysisConfigScreen extends ConsumerWidget {
  const AiAnalysisConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(llmModeProvider);
    final isRemote = mode == LlmMode.remote;
    final isLocal = mode == LlmMode.local;
    final theme = Theme.of(context);

    if (mode == LlmMode.off) {
      return Scaffold(
        appBar: AppBar(title: Text(S.of(context).aiConfig)),
        body: Center(
          child: Text(
            S.of(context).modeOffDescription,
            style: theme.textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // LlmConfig 和 LocalLlmConfig 字段相同，用 dynamic 避免联合类型问题
    final dynamic config = isRemote
        ? ref.watch(llmConfigProvider)
        : ref.watch(localLlmConfigProvider);

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).aiConfig)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 当前模式提示
          Card(
            child: ListTile(
              leading: Icon(
                isRemote ? Icons.cloud_outlined : Icons.phone_android_outlined,
                color: theme.colorScheme.primary,
              ),
              title: Text(isRemote
                  ? S.of(context).modeRemoteApi
                  : S.of(context).modeLocalModel),
              subtitle: Text(
                isRemote
                    ? '${ref.watch(llmConfigProvider).model}'
                    : ref.watch(localLlmConfigProvider).modelPath?.split('/').last ?? '',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 16),
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
      ),
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
