import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

/// AI 分析配置页面（关于页面入口）
/// - 远程 API：分析参数（temperature / maxTokens / prompt / 压缩）
/// - 本地模型：分析参数 + 本地模型配置（GPU / 上下文长度 / 高级性能）
class AiAnalysisConfigScreen extends ConsumerStatefulWidget {
  const AiAnalysisConfigScreen({super.key});

  @override
  ConsumerState<AiAnalysisConfigScreen> createState() => _AiAnalysisConfigScreenState();
}

class _AiAnalysisConfigScreenState extends ConsumerState<AiAnalysisConfigScreen> {
  String _defaultSystemPrompt = '';
  String _defaultUserPrompt = '';
  bool _loaded = false;
  late TextEditingController _systemController;
  late TextEditingController _userController;
  bool _syncingText = false; // guard: 防止 didUpdateWidget 更新 controller 时触发 onChanged

  @override
  void initState() {
    super.initState();
    _systemController = TextEditingController();
    _userController = TextEditingController();
    _loadDefaultPrompts();
  }

  @override
  void didUpdateWidget(AiAnalysisConfigScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 恢复默认时，同步 controller 文本（加 guard 防止覆盖用户正在输入的内容）
    if (_loaded && !_syncingText && _defaultSystemPrompt.isNotEmpty) {
      _syncingText = true;
      final mode = ref.read(llmModeProvider);
      final isRemote = mode == LlmMode.remote;
      final dynamic cfg = isRemote
          ? ref.read(llmConfigProvider)
          : ref.read(localLlmConfigProvider);
      final newSys = cfg.customSystemPrompt ?? _defaultSystemPrompt;
      final newUsr = cfg.customUserPrompt ?? _defaultUserPrompt;
      if (_systemController.text != newSys) {
        _systemController.text = newSys;
      }
      if (_userController.text != newUsr) {
        _userController.text = newUsr;
      }
      _syncingText = false;
    }
  }

  @override
  void dispose() {
    _systemController.dispose();
    _userController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultPrompts() async {
    final locale = PlatformDispatcher.instance.locale;
    final isChinese = locale.languageCode.startsWith('zh');
    final systemFile = isChinese ? 'vision_system_zh.txt' : 'vision_system_en.txt';
    final userFile = isChinese ? 'vision_user_zh.txt' : 'vision_user_en.txt';
    try {
      final system = await rootBundle.loadString('assets/prompts/$systemFile');
      final user = await rootBundle.loadString('assets/prompts/$userFile');
      if (mounted) {
        setState(() {
          _defaultSystemPrompt = system;
          _defaultUserPrompt = user;
          _loaded = true;
          // 初始化 controller 文本
          _systemController.text = system;
          _userController.text = user;
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
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

    final effectiveSystem = config.customSystemPrompt ?? _defaultSystemPrompt;
    final effectiveUser = config.customUserPrompt ?? _defaultUserPrompt;

    return Scaffold(
      appBar: AppBar(title: Text(S.of(context).aiConfig)),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
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

                // ===== 分析参数（远程 + 本地都显示） =====
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
                        Row(
                          children: [
                            Text('System Prompt', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            if (config.customSystemPrompt != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '已自定义',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _updateConfig(
                                ref,
                                isRemote,
                                config.copyWith(clearSystemPrompt: true),
                              ),
                              child: const Text('恢复默认'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '系统提示词模板，影响标签生成规则和质量',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _systemController,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          maxLines: 6,
                          onChanged: (v) {
                            if (_syncingText) return;
                            final trimmed = v.trim();
                            if (trimmed == _defaultSystemPrompt) {
                              _updateConfig(ref, isRemote, config.copyWith(clearSystemPrompt: true));
                            } else {
                              _updateConfig(ref, isRemote, config.copyWith(customSystemPrompt: trimmed));
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        // 自定义 User Prompt
                        Row(
                          children: [
                            Text('User Prompt', style: theme.textTheme.bodyMedium),
                            const SizedBox(width: 8),
                            if (config.customUserPrompt != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '已自定义',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: theme.colorScheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => _updateConfig(
                                ref,
                                isRemote,
                                config.copyWith(clearUserPrompt: true),
                              ),
                              child: const Text('恢复默认'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '用户提示词，影响分析时的引导语',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _userController,
                          decoration: const InputDecoration(border: OutlineInputBorder()),
                          maxLines: 2,
                          onChanged: (v) {
                            if (_syncingText) return;
                            final trimmed = v.trim();
                            if (trimmed == _defaultUserPrompt) {
                              _updateConfig(ref, isRemote, config.copyWith(clearUserPrompt: true));
                            } else {
                              _updateConfig(ref, isRemote, config.copyWith(customUserPrompt: trimmed));
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // ===== 本地模型配置（仅本地模式） =====
                if (isLocal) ...[
                  const SizedBox(height: 16),
                  Text('本地模型配置', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
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
                            value: ref.watch(localLlmConfigProvider).useGpu,
                            onChanged: (v) {
                              ref.read(localLlmConfigProvider.notifier).update(
                                ref.read(localLlmConfigProvider).copyWith(useGpu: v),
                              );
                              if (ref.read(localLlmLoadedProvider)) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('GPU 设置已修改，下次分析时生效'),
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
                              value: ref.watch(localLlmConfigProvider).contextSize,
                              underline: const SizedBox(),
                              items: [512, 1024, 2048, 4096].map((n) {
                                return DropdownMenuItem(value: n, child: Text('$n'));
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) {
                                  ref.read(localLlmConfigProvider.notifier).update(
                                    ref.read(localLlmConfigProvider).copyWith(contextSize: v),
                                  );
                                  if (ref.read(localLlmLoadedProvider)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('上下文长度已修改，下次分析时生效'),
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
                  const SizedBox(height: 8),
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
                            value: ref.watch(localLlmConfigProvider).flashAttn,
                            decoration: const InputDecoration(
                              labelText: 'Flash Attention',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: [
                              DropdownMenuItem(value: FlashAttnMode.auto, child: Text('自动（根据 GPU 决定）')),
                              DropdownMenuItem(value: FlashAttnMode.enabled, child: Text('启用')),
                              DropdownMenuItem(value: FlashAttnMode.disabled, child: Text('禁用')),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(localLlmConfigProvider.notifier).update(
                                ref.read(localLlmConfigProvider).copyWith(flashAttn: v),
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          // KV 缓存量化
                          DropdownButtonFormField<KvCacheType>(
                            value: ref.watch(localLlmConfigProvider).kvCacheType,
                            decoration: const InputDecoration(
                              labelText: 'KV 缓存量化',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: [
                              DropdownMenuItem(value: KvCacheType.f16, child: Text('F16（精度高）')),
                              DropdownMenuItem(value: KvCacheType.q4_0, child: Text('Q4_0（省内存）')),
                            ],
                            onChanged: (v) {
                              if (v != null) ref.read(localLlmConfigProvider.notifier).update(
                                ref.read(localLlmConfigProvider).copyWith(kvCacheType: v),
                              );
                            },
                          ),
                          if (ref.watch(localLlmConfigProvider).kvCacheType == KvCacheType.q4_0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Q4_0 可显著降低 KV 缓存内存占用，适合 4GB 以下内存设备',
                                style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
                              ),
                            ),
                          const SizedBox(height: 12),
                          // 统一 KV 缓存
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('统一 KV 缓存'),
                            subtitle: Text(
                              '开启后多个推理任务共享 KV 缓存，省内存；关闭则每个任务独立 KV 缓存，用满上下文但占更多内存',
                              style: theme.textTheme.bodySmall,
                            ),
                            value: ref.watch(localLlmConfigProvider).kvUnified,
                            onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                              ref.read(localLlmConfigProvider).copyWith(kvUnified: v),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // use_mmap
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('使用 mmap 加载'),
                            subtitle: Text('内存映射文件加载（Android 低内存设备建议关闭）',
                                style: theme.textTheme.bodySmall),
                            value: ref.watch(localLlmConfigProvider).useMmap,
                            onChanged: (v) => ref.read(localLlmConfigProvider.notifier).update(
                              ref.read(localLlmConfigProvider).copyWith(useMmap: v),
                            ),
                          ),
                          const SizedBox(height: 16),
                          // n_batch / n_ubatch
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  initialValue: ref.watch(localLlmConfigProvider).nBatch.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Batch 大小',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n > 0) ref.read(localLlmConfigProvider.notifier).update(
                                      ref.read(localLlmConfigProvider).copyWith(nBatch: n),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  initialValue: ref.watch(localLlmConfigProvider).nUBatch.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'UBatch 大小',
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    isDense: true,
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (v) {
                                    final n = int.tryParse(v);
                                    if (n != null && n > 0) ref.read(localLlmConfigProvider.notifier).update(
                                      ref.read(localLlmConfigProvider).copyWith(nUBatch: n),
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
