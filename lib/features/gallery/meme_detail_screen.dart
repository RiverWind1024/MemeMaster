import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import 'gallery_provider.dart';

class MemeDetailScreen extends ConsumerStatefulWidget {
  final String memeId;

  const MemeDetailScreen({super.key, required this.memeId});

  @override
  ConsumerState<MemeDetailScreen> createState() => _MemeDetailScreenState();
}

class _MemeDetailScreenState extends ConsumerState<MemeDetailScreen> {
  int _refreshTrigger = 0;

  Meme? _cachedMeme;

  Future<Meme?> _fetchMeme() => ref.read(memeRepositoryProvider).getById(widget.memeId);

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(memeRepositoryProvider);
    final storage = ref.read(fileStorageServiceProvider);

    return FutureBuilder<Meme?>(
      key: ValueKey('meme_${widget.memeId}_$_refreshTrigger'),
      future: _fetchMeme(),
      builder: (context, snapshot) {
        final meme = snapshot.data;
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(title: const Text('加载中...')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (meme == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('未找到')),
            body: const Center(child: Text('Meme 不存在')),
          );
        }
        _cachedMeme = meme;

        return Scaffold(
          appBar: AppBar(
            title: Text(meme.filename),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _reanalyze(context, ref, meme),
                tooltip: '重新分析',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteMeme(context, ref, meme),
                tooltip: '删除',
              ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 图片
                FutureBuilder(
                  future: storage.getImage(meme.filePath),
                  builder: (context, fileSnapshot) {
                    if (!fileSnapshot.hasData) {
                      return const AspectRatio(
                        aspectRatio: 1,
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    return Image.file(
                      fileSnapshot.data!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, _, _) => const AspectRatio(
                        aspectRatio: 1,
                        child: Icon(Icons.broken_image, size: 64),
                      ),
                    );
                  },
                ),

                // 信息
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 分析状态 + 操作按钮
                      Row(
                        children: [
                          _StatusChip(status: meme.analysisStatus),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _OcrAiStatus(memeId: widget.memeId),
                      const SizedBox(height: 16),

                      // 文件信息
                      _InfoRow(label: '文件名', value: meme.filename),
                      _InfoRow(
                          label: '尺寸',
                          value: '${meme.width} × ${meme.height}'),
                      _InfoRow(
                          label: '大小',
                          value: _formatSize(meme.fileSize)),

                      const SizedBox(height: 16),

                      // 颜色
                      _ColorPalette(memeId: widget.memeId),
                      const SizedBox(height: 16),

                      // OCR 标签
                      _OcrTags(memeId: widget.memeId),
                      const SizedBox(height: 16),

                      // 自定义标签
                      _CustomTags(memeId: widget.memeId),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _reanalyze(
      BuildContext context, WidgetRef ref, Meme meme) async {
    final repo = ref.read(memeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      // 1. 清除旧数据（只清除自动生成的，保留用户自定义标签）
      await repo.deleteColors(meme.id);
      await repo.deleteAutoTags(meme.id);

      // 2. 重置分析状态
      await repo.updateAnalysisStatus(meme.id, 'pending');

      // 3. 入队新分析任务
      await repo.enqueueAnalysis(meme.id, priority: 1);

      // 4. 刷新页面
      setState(() => _refreshTrigger++);

      if (mounted) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('已加入分析队列，即将开始分析'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('重新分析失败: $e')),
        );
      }
    }
  }

  Future<void> _deleteMeme(
      BuildContext context, WidgetRef ref, Meme meme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除「${meme.filename}」吗？\n图片文件和所有分析数据都会被移除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(memeRepositoryProvider).delete(meme.id);
      ref.invalidate(memeListProvider);
      ref.invalidate(memeCountProvider);
      if (context.mounted) context.pop();
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'done' => ('颜色提取完成', Colors.green, Icons.check_circle_outline),
      'processing' => ('正在提取颜色...', Colors.orange, Icons.sync),
      'failed' => ('颜色提取失败', Colors.red, Icons.error_outline),
      _ => ('待提取主色调', Colors.grey, Icons.hourglass_empty),
    };

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

/// OCR + AI 识别状态指示
class _OcrAiStatus extends ConsumerWidget {
  final String memeId;

  const _OcrAiStatus({required this.memeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ocrEnabled = ref.watch(ocrEnabledProvider);
    final llmEnabled = ref.watch(llmEnabledProvider);

    return Row(
      children: [
        // OCR
        Icon(Icons.text_fields, size: 14,
            color: ocrEnabled ? Colors.blue : Colors.grey),
        const SizedBox(width: 4),
        Text(
          ocrEnabled ? 'OCR 已开启' : '未开启 OCR 识别',
          style: TextStyle(
            fontSize: 12,
            color: ocrEnabled ? Colors.blue : Colors.grey,
          ),
        ),
        const SizedBox(width: 16),
        // AI
        Icon(Icons.auto_awesome, size: 14,
            color: llmEnabled ? Colors.purple : Colors.grey),
        const SizedBox(width: 4),
        Text(
          llmEnabled ? 'AI 已开启' : '未开启 AI 识别',
          style: TextStyle(
            fontSize: 12,
            color: llmEnabled ? Colors.purple : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            child: Text(label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    )),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ColorPalette extends ConsumerWidget {
  final String memeId;

  const _ColorPalette({required this.memeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(memeRepositoryProvider);
    final theme = Theme.of(context);

    return FutureBuilder<Meme?>(
      future: repo.getById(memeId),
      builder: (context, memeSnapshot) {
        final meme = memeSnapshot.data;
        final status = meme?.analysisStatus ?? 'pending';

        return FutureBuilder<List<ColorEntry>>(
          future: repo.getColors(memeId),
          builder: (context, snapshot) {
            final hasColors = snapshot.hasData && snapshot.data!.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('主色调',
                        style: theme.textTheme.titleSmall),
                    const SizedBox(width: 8),
                    if (status == 'processing')
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (hasColors)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: snapshot.data!.map((c) {
                      final hex = c.hexColor;
                      final color = Color(
                          int.parse(hex.replaceFirst('#', '0xFF')));
                      final ratio = c.ratio;
                      return Tooltip(
                        message: '$hex  ${(ratio * 100).toStringAsFixed(0)}%',
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else if (status == 'done' || status == 'failed')
                  Text('未提取到主色调',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ))
                else
                  Text('正在提取主色调...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      )),
              ],
            );
          },
        );
      },
    );
  }
}

/// 自定义标签（用户手动添加）
class _CustomTags extends ConsumerStatefulWidget {
  final String memeId;
  const _CustomTags({required this.memeId});

  @override
  ConsumerState<_CustomTags> createState() => _CustomTagsState();
}

class _CustomTagsState extends ConsumerState<_CustomTags> {
  final _controller = TextEditingController();
  int _refresh = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<List<TagEntry>> _fetchTags() async {
    final all = await ref.read(memeRepositoryProvider).getTags(widget.memeId);
    return all.where((t) => t.source == 'custom').toList();
  }

  Future<void> _addTag() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final repo = ref.read(memeRepositoryProvider);
    await repo.saveTags([
      TagEntry(
        id: '${widget.memeId}_custom_${text.hashCode}',
        memeId: widget.memeId,
        content: text,
        source: 'custom',
        confidence: 1.0,
      ),
    ]);
    _controller.clear();
    setState(() => _refresh++);
  }

  Future<void> _removeTag(TagEntry tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除标签'),
        content: Text('确定删除标签「${tag.content}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('删除',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(memeRepositoryProvider);
    // 用 deleteByMemeId + 重新保存其他标签来实现打点删除
    // 更干净的方式：通过 dao 删除单条，这里用简化方案
    final all = await repo.getTags(widget.memeId);
    final remaining = all.where((t) => t.id != tag.id).toList();
    await repo.deleteTags(widget.memeId);
    if (remaining.isNotEmpty) {
      await repo.saveTags(remaining);
    }
    setState(() => _refresh++);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<List<TagEntry>>(
      key: ValueKey('custom_tags_$_refresh'),
      future: _fetchTags(),
      builder: (context, snapshot) {
        final tags = snapshot.data ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.label_outline, size: 16, color: Colors.green),
                const SizedBox(width: 6),
                Text('自定义标签', style: theme.textTheme.titleSmall),
                if (tags.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${tags.length} 个',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (tags.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags.map((tag) {
                  return GestureDetector(
                    onTap: () => _removeTag(tag),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag.content,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.green.shade700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.close, size: 12, color: Colors.green.shade400),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '暂无自定义标签',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: TextField(
                      controller: _controller,
                      decoration: const InputDecoration(
                        hintText: '输入标签',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _addTag(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 36,
                  child: FilledButton.tonalIcon(
                    onPressed: _addTag,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('添加'),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// OCR 标签展示
class _OcrTags extends ConsumerWidget {
  final String memeId;

  const _OcrTags({required this.memeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(memeRepositoryProvider);
    final theme = Theme.of(context);

    return FutureBuilder<List<TagEntry>>(
      future: repo.getTags(memeId),
      builder: (context, snapshot) {
        final hasOcr = snapshot.hasData &&
            snapshot.data!.any((t) => t.source == 'ocr');
        final ocrTags = snapshot.data?.where((t) => t.source == 'ocr').toList() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.text_fields, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text('OCR 识别', style: theme.textTheme.titleSmall),
                if (hasOcr) ...[
                  const SizedBox(width: 6),
                  Text(
                    '${ocrTags.length} 词',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (hasOcr)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: ocrTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      tag.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.blue.shade700,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                '暂未识别到文字',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
          ],
        );
      },
    );
  }
}
