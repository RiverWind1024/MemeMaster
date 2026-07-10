import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/database.dart';
import 'gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class MemeDetailScreen extends ConsumerStatefulWidget {
  final String memeId;

  const MemeDetailScreen({super.key, required this.memeId});

  @override
  ConsumerState<MemeDetailScreen> createState() => _MemeDetailScreenState();
}

class _MemeDetailScreenState extends ConsumerState<MemeDetailScreen> {
  int _currentIndex = 0;
  late PageController _pageCtrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _reanalyze(BuildContext context, WidgetRef ref, Meme meme) async {
    final repo = ref.read(memeRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await repo.deleteColors(meme.id);
      await repo.deleteAutoTags(meme.id);
      await repo.updateAnalysisStatus(meme.id, 'pending');
      await repo.enqueueAnalysis(meme.id, priority: 1);

      // 刷新列表以反映状态变化
      ref.invalidate(memeListProvider);

      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(S.of(context).addedToAnalysisQueue),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text(S.of(context).reanalysisFailed(e.toString()))),
        );
      }
    }
  }

  Future<void> _deleteMeme(BuildContext context, WidgetRef ref, Meme meme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).confirmDeleteTitle),
        content: Text(S.of(context).confirmDeleteMeme(meme.filename)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).delete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(memeRepositoryProvider).delete(meme.id);
        ref.invalidate(memeListProvider);
        ref.invalidate(memeCountProvider);
        if (context.mounted) context.pop();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final memeListAsync = ref.watch(memeListProvider);

    return memeListAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(S.of(context).loading)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: Text(S.of(context).loadFailed)),
        body: Center(child: Text('$e')),
      ),
      data: (memes) {
        final initialIndex = memes.indexWhere((m) => m.id == widget.memeId);
        if (initialIndex < 0) {
          return Scaffold(
            appBar: AppBar(title: Text(S.of(context).notFound)),
            body: Center(child: Text(S.of(context).memeNotExist)),
          );
        }

        // 延迟一帧初始化 PageController 的初始位置
        if (!_initialized) {
          _initialized = true;
          _currentIndex = initialIndex;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageCtrl.hasClients && _pageCtrl.page != initialIndex.toDouble()) {
              _pageCtrl.jumpToPage(initialIndex);
            }
          });
        }

        final currentMeme = memes[_currentIndex];

        return Scaffold(
          appBar: AppBar(
            title: Text(currentMeme.filename),
            actions: [
              if (memes.length > 1)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    '${_currentIndex + 1}/${memes.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => _reanalyze(context, ref, currentMeme),
                tooltip: S.of(context).reAnalyze,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _deleteMeme(context, ref, currentMeme),
                tooltip: S.of(context).delete,
              ),
            ],
          ),
          body: PageView.builder(
            controller: _pageCtrl,
            itemCount: memes.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return _MemeDetailPage(
                meme: memes[index],
                memeId: memes[index].id,
              );
            },
          ),
        );
      },
    );
  }

}

class _MemeDetailPage extends ConsumerStatefulWidget {
  final Meme meme;
  final String memeId;

  const _MemeDetailPage({required this.meme, required this.memeId});

  @override
  ConsumerState<_MemeDetailPage> createState() => _MemeDetailPageState();
}

class _MemeDetailPageState extends ConsumerState<_MemeDetailPage> {
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _maybeStartPolling();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  /// 当分析未完成时，定时刷新 memeListProvider 以反映进度
  void _maybeStartPolling() {
    _pollTimer?.cancel();
    if (widget.meme.analysisStatus == 'pending' ||
        widget.meme.analysisStatus == 'processing') {
      _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        ref.invalidate(memeListProvider);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _MemeDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 状态变为终态时停止轮询
    final status = widget.meme.analysisStatus;
    if (status != 'pending' && status != 'processing') {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = ref.read(fileStorageServiceProvider);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 图片
          FutureBuilder(
            future: storage.getImage(widget.meme.filePath),
            builder: (context, fileSnapshot) {
              if (!fileSnapshot.hasData) {
                return const AspectRatio(
                  aspectRatio: 1,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return GestureDetector(
                onTap: () => _showFullscreen(context, ref, fileSnapshot.data!),
                child: Image.file(
                  fileSnapshot.data!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const AspectRatio(
                    aspectRatio: 1,
                    child: Icon(Icons.broken_image, size: 64),
                  ),
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
                // 状态、OCR、AI 三行合并为一行并排展示
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _StatusChip(status: widget.meme.colorAnalysisStatus),
                      const SizedBox(width: 16),
                      _OcrChip(memeId: widget.memeId),
                      const SizedBox(width: 16),
                      _AiChip(memeId: widget.memeId),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                _InfoRow(label: S.of(context).fileName, value: widget.meme.filename),
                _InfoRow(
                    label: S.of(context).dimensions,
                    value: '${widget.meme.width} × ${widget.meme.height}'),
                _InfoRow(
                    label: S.of(context).fileSize,
                    value: _formatSize(widget.meme.fileSize)),

                const SizedBox(height: 16),

                _ColorPalette(memeId: widget.memeId),
                const SizedBox(height: 16),

                _OcrTags(memeId: widget.memeId),
                const SizedBox(height: 16),

                _LlmTags(memeId: widget.memeId),
                const SizedBox(height: 16),

                _Description(meme: widget.meme),
                const SizedBox(height: 16),

                _CustomTags(memeId: widget.memeId),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showFullscreen(BuildContext context, WidgetRef ref, File file) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text(''),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.file(file, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'done' => (S.of(context).colorExtractionDone, Colors.green, Icons.check_circle_outline),
      'processing' => (S.of(context).colorExtracting, Colors.orange, Icons.sync),
      'failed' => (S.of(context).colorExtractionFailed, Colors.red, Icons.error_outline),
      _ => (S.of(context).pendingColorExtraction, Colors.grey, Icons.hourglass_empty),
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

/// OCR 状态指示（单独一行）
class _OcrChip extends ConsumerWidget {
  final String memeId;
  const _OcrChip({required this.memeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(ocrEnabledProvider);
    return Row(children: [
      Icon(Icons.text_fields, size: 14, color: enabled ? Colors.blue : Colors.grey),
      const SizedBox(width: 6),
      Text(enabled ? S.of(context).ocrEnabled : S.of(context).ocrDisabled,
          style: TextStyle(fontSize: 13, color: enabled ? Colors.blue : Colors.grey)),
    ]);
  }
}

/// AI 识别状态指示（单独一行）
class _AiChip extends ConsumerWidget {
  final String memeId;
  const _AiChip({required this.memeId});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 检查 AI 是否真正可用（而不仅仅是手动开关）
    final llmService = ref.watch(llmServiceProvider);
    final aiAvailable = llmService != null && llmService.isAvailable;
    return Row(children: [
      Icon(Icons.auto_awesome, size: 14, color: aiAvailable ? Colors.purple : Colors.grey),
      const SizedBox(width: 6),
      Text(aiAvailable ? S.of(context).aiEnabled : S.of(context).aiDisabled,
          style: TextStyle(fontSize: 13, color: aiAvailable ? Colors.purple : Colors.grey)),
    ]);
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
                    Text(S.of(context).dominantColors,
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
                  Text(S.of(context).noDominantColors,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ))
                else
                  Text(S.of(context).extractingDominantColors,
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
  final _focusNode = FocusNode();
  int _refresh = 0;
  bool _showInput = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
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

  void _toggleInput() {
    setState(() => _showInput = !_showInput);
    if (_showInput) {
      _controller.clear();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _focusNode.requestFocus();
      });
    } else {
      _controller.clear();
      _focusNode.unfocus();
    }
  }

  void _onSubmitted(String _) {
    _addTag();
  }

  Future<void> _removeTag(TagEntry tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).deleteTag),
        content: Text(S.of(context).confirmDeleteTag(tag.content)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(S.of(context).cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(S.of(context).delete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(memeRepositoryProvider);
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
                Text(S.of(context).customTags, style: theme.textTheme.titleSmall),
                if (tags.isNotEmpty) ...[
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).tagCount(tags.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: _toggleInput,
                  child: Icon(
                    _showInput ? Icons.close : Icons.add,
                    size: 18,
                    color: Colors.green,
                  ),
                ),
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
            else if (!_showInput)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  S.of(context).noCustomTags,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
            if (_showInput) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        decoration: InputDecoration(
                          hintText: S.of(context).inputTag,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        textInputAction: TextInputAction.done,
                        onSubmitted: _onSubmitted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: FilledButton.tonalIcon(
                      onPressed: _addTag,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(S.of(context).add),
                    ),
                  ),
                ],
              ),
            ],
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
                Text(S.of(context).ocrRecognition, style: theme.textTheme.titleSmall),
                if (hasOcr) ...[
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).ocrWordCount(ocrTags.length),
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
                S.of(context).noOcrText,
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

/// LLM 标签展示
class _LlmTags extends ConsumerWidget {
  final String memeId;

  const _LlmTags({required this.memeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(memeRepositoryProvider);
    final theme = Theme.of(context);

    return FutureBuilder<List<TagEntry>>(
      future: repo.getTags(memeId),
      builder: (context, snapshot) {
        final llmTags = snapshot.data?.where((t) => t.source == 'llm').toList() ?? [];
        final hasLlm = llmTags.isNotEmpty;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: Colors.purple),
                const SizedBox(width: 6),
                Text(S.of(context).aiRecognition, style: theme.textTheme.titleSmall),
                if (hasLlm) ...[
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).llmTagCount(llmTags.length),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            if (hasLlm)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: llmTags.map((tag) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      tag.content,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.purple.shade700,
                      ),
                    ),
                  );
                }).toList(),
              )
            else
              Text(
                S.of(context).noAiTags,
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

/// 描述展示（由 LLM 生成）
class _Description extends StatelessWidget {
  final Meme meme;

  const _Description({required this.meme});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final desc = meme.description;

    if (desc == null || desc.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.short_text, size: 16, color: Colors.orange),
            const SizedBox(width: 6),
            Text(S.of(context).descriptionLabel, style: theme.textTheme.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          desc,
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );
  }
}
