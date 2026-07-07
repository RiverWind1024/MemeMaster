import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/llm/local_config.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

/// 本地模型详细配置页面
/// 包含：GPU 加速、上下文长度、高级性能配置（Flash Attention / KV 缓存 / Batch 等）
class LocalModelConfigScreen extends ConsumerWidget {
  const LocalModelConfigScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localConfig = ref.watch(localLlmConfigProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).localModelConfig),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // GPU 加速
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(S.of(context).gpuAcceleration),
                    value: localConfig.useGpu,
                    onChanged: (v) {
                      ref.read(localLlmConfigProvider.notifier).update(
                        localConfig.copyWith(useGpu: v),
                      );
                      if (ref.read(localLlmLoadedProvider)) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('GPU 设置已修改，请重新加载模型以生效'),
                            duration: Duration(seconds: 3),
                          ),
                        );
                      }
                    },
                    secondary: const Icon(Icons.memory),
                  ),
                  const Divider(),
                  // 上下文长度
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
                          if (ref.read(localLlmLoadedProvider)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('上下文长度已修改，请重新加载模型以生效'),
                                duration: Duration(seconds: 3),
                              ),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // 高级性能配置
          Text('高级性能配置', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Flash Attention
                  DropdownButtonFormField<FlashAttnMode>(
                    value: localConfig.flashAttn,
                    decoration: InputDecoration(
                      labelText: 'Flash Attention',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem(value: FlashAttnMode.auto, child: Text('自动（根据 GPU 决定）')),
                      DropdownMenuItem(value: FlashAttnMode.enabled, child: Text('启用')),
                      DropdownMenuItem(value: FlashAttnMode.disabled, child: Text('禁用')),
                    ],
                    onChanged: (v) {
                      if (v != null) ref.read(localLlmConfigProvider.notifier).update(
                        localConfig.copyWith(flashAttn: v),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  // KV 缓存量化类型
                  DropdownButtonFormField<KvCacheType>(
                    value: localConfig.kvCacheType,
                    decoration: InputDecoration(
                      labelText: 'KV 缓存量化',
                      hintText: 'F16（默认）',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    items: [
                      DropdownMenuItem(value: KvCacheType.f16, child: Text('F16（精度高）')),
                      DropdownMenuItem(value: KvCacheType.q4_0, child: Text('Q4_0（省内存）')),
                    ],
                    onChanged: (v) {
                      if (v != null) ref.read(localLlmConfigProvider.notifier).update(
                        localConfig.copyWith(kvCacheType: v),
                      );
                    },
                  ),
                  if (localConfig.kvCacheType == KvCacheType.q4_0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Q4_0 可显著降低 KV 缓存内存占用，适合 4GB 以下内存设备',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange)),
                    ),
                  const SizedBox(height: 12),
                  // 统一 KV 缓存
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('统一 KV 缓存'),
                    subtitle: Text('将 K 和 V 合并存储，减少内存碎片',
                        style: theme.textTheme.bodySmall),
                    value: localConfig.kvUnified,
                    onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                      localConfig.copyWith(kvUnified: v),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // use_mmap
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('使用 mmap 加载'),
                    subtitle: Text('内存映射文件加载（Android 低内存设备建议关闭）',
                        style: theme.textTheme.bodySmall),
                    value: localConfig.useMmap,
                    onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                      localConfig.copyWith(useMmap: v),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // n_batch / n_ubatch
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: localConfig.nBatch.toString(),
                          decoration: const InputDecoration(
                            labelText: 'Batch 大小',
                            hintText: '512',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) ref.read(localLlmConfigProvider.notifier).update(
                              localConfig.copyWith(nBatch: n),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: localConfig.nUBatch.toString(),
                          decoration: const InputDecoration(
                            labelText: 'UBatch 大小',
                            hintText: '256',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (v) {
                            final n = int.tryParse(v);
                            if (n != null && n > 0) ref.read(localLlmConfigProvider.notifier).update(
                              localConfig.copyWith(nUBatch: n),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
