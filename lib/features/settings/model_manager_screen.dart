import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';

import '../../core/llm/local_config.dart';
import '../../core/llm/model_manager.dart';
import '../../services/model_search_service.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

/// 当前选中的下载源
final selectedSourceProvider = StateProvider<DownloadSource>((ref) => DownloadSource.modelscope);

/// 搜索关键词
final searchQueryProvider = StateProvider<String>((ref) => '');

/// 搜索结果
final searchResultsProvider = StateProvider<List<SearchableModel>>((ref) => []);

/// 是否正在搜索
final isSearchingProvider = StateProvider<bool>((ref) => false);

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ModelSearchService _searchService = ModelSearchService();

  @override
  void dispose() {
    _searchController.dispose();
    _searchService.dispose();
    super.dispose();
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    ref.read(searchResultsProvider.notifier).state = [];
    ref.read(isSearchingProvider.notifier).state = true;

    try {
      final source = ref.read(selectedSourceProvider);
      final results = await _searchService.search(
        source: source,
        query: query,
        limit: 20,
      );
      ref.read(searchResultsProvider.notifier).state = results;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('搜索失败: $e')),
        );
      }
    } finally {
      ref.read(isSearchingProvider.notifier).state = false;
    }
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchResultsProvider.notifier).state = [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final source = ref.watch(selectedSourceProvider);
    final isSearching = ref.watch(isSearchingProvider);
    final searchResults = ref.watch(searchResultsProvider);
    final hasSearch = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).modelManager),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. 下载源选择 + 搜索
          _buildSearchSection(theme, source, isSearching, hasSearch),
          const SizedBox(height: 16),

          // 2. 搜索结果或推荐模型
          if (hasSearch) ...[
            Text('搜索结果', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (isSearching)
              const Center(child: CircularProgressIndicator())
            else if (searchResults.isEmpty)
              _buildEmptyCard('未找到相关模型')
            else
              ...searchResults.map((model) => _SearchResultCard(
                    model: model,
                    onDownload: () => _showGgufFilesDialog(model),
                  )),
          ] else ...[
            Text('推荐模型', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._buildRecommendedModels(source),
          ],
          const SizedBox(height: 24),

          // 3. 下载中的模型
          _buildDownloadingSection(theme),
          const SizedBox(height: 24),

          // 4. 已下载的模型
          _buildDownloadedSection(theme),
        ],
      ),
    );
  }

  Widget _buildSearchSection(
    ThemeData theme,
    DownloadSource source,
    bool isSearching,
    bool hasSearch,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 下载源选择
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<DownloadSource>(
                    value: source,
                    decoration: const InputDecoration(
                      labelText: '下载源',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: DownloadSource.huggingface,
                        child: Text('HuggingFace'),
                      ),
                      DropdownMenuItem(
                        value: DownloadSource.modelscope,
                        child: Text('ModelScope'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        ref.read(selectedSourceProvider.notifier).state = value;
                        _clearSearch();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // 搜索框
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜索模型 (例如: qwen, llama, moondream)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: hasSearch
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _performSearch(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isSearching ? null : _performSearch,
                    icon: isSearching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('搜索'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRecommendedModels(DownloadSource source) {
    final models = ModelManager.recommendedModels[source] ?? [];
    final manager = ref.read(modelManagerProvider);
    final downloaded = manager.getDownloadedModels();
    final downloadStates = ref.watch(downloadStatesProvider);

    if (models.isEmpty) {
      return [_buildEmptyCard('暂无推荐模型')];
    }

    return models.map((model) {
      // 检查该模型是否有任何下载任务在进行中
      final taskId = DownloadStatesNotifier.makeTaskId(model.id, 'gguf');
      final hasDownloadTask = downloadStates.containsKey(taskId);
      return _ModelCard(
        model: model,
        isDownloaded: downloaded.any((d) => d.id == model.id),
        downloadState: hasDownloadTask ? downloadStates[taskId] : null,
      );
    }).toList();
  }

  Widget _buildDownloadingSection(ThemeData theme) {
    final downloadStates = ref.watch(downloadStatesProvider);
    final downloading = downloadStates.entries
        .where((e) => e.value.status == DownloadStatus.downloading || e.value.status == DownloadStatus.paused)
        .toList();

    if (downloading.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('下载中', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...downloading.map((entry) => _DownloadingCard(
              modelId: entry.key,
              state: entry.value,
            )),
      ],
    );
  }

  Widget _buildDownloadedSection(ThemeData theme) {
    final manager = ref.read(modelManagerProvider);
    final downloaded = manager.getDownloadedModels();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('已下载', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (downloaded.isEmpty)
          _buildEmptyCard('暂无已下载的模型')
        else
          ...downloaded.map((d) => _DownloadedModelCard(model: d)),
      ],
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      ),
    );
  }

  Future<void> _showGgufFilesDialog(SearchableModel model) async {
    final source = ref.read(selectedSourceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(model.name),
        content: const SizedBox(
          width: double.infinity,
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final files = await _searchService.getGgufFiles(
        source: source,
        modelId: model.id,
      );
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (files.isEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('未找到 GGUF 文件'),
            content: const Text('该模型仓库中没有找到 .gguf 文件。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      // Show file selection dialog
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('选择要下载的文件'),
          content: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: files.map((file) {
                final fileName = file.path.split('/').last;
                final isMmproj = fileName.toLowerCase().contains('mmproj');
                return ListTile(
                  title: Text(fileName),
                  subtitle: Text(_formatBytes(file.size)),
                  trailing: const Icon(Icons.download),
                  onTap: () {
                    Navigator.pop(ctx);
                    _startDownloadFromSearch(model, file, isMmproj: isMmproj);
                  },
                );
              }).toList(),
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('获取文件列表失败'),
          content: Text('错误: $e'),
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

  void _startDownloadFromSearch(SearchableModel model, ModelFileInfo file, {bool isMmproj = false}) {
    final source = ref.read(selectedSourceProvider);
    final fileType = isMmproj ? 'mmproj' : 'gguf';
    final taskId = DownloadStatesNotifier.makeTaskId(model.id, fileType);
    
    final modelInfo = ModelInfo(
      id: model.id,
      name: model.name,
      description: model.description ?? '',
      source: source,
      ggufUrl: file.downloadUrl,
      sizeLabel: _formatBytes(file.size),
    );

    final notifier = ref.read(downloadStatesProvider.notifier);
    notifier.startDownload(taskId);
    final cancelToken = notifier.getCancelToken(taskId);

    final manager = ref.read(modelManagerProvider);
    manager.downloadModel(
      modelInfo,
      onProgress: (p) => notifier.updateProgress(taskId, p),
      cancelToken: cancelToken,
    ).then((_) {
      notifier.completeDownload(taskId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${model.name} ${isMmproj ? "mmproj" : "gguf"} 下载完成')),
        );
      }
    }).catchError((e) {
      // 暂停不算失败
      if (e is PauseException) {
        return;
      }
      notifier.failDownload(taskId, e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    });
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

/// 搜索结果卡片
class _SearchResultCard extends StatelessWidget {
  final SearchableModel model;
  final VoidCallback onDownload;

  const _SearchResultCard({
    required this.model,
    required this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.name, style: theme.textTheme.titleSmall),
                ),
                Text('${model.downloads} 次下载', style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(model.author, style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                )),
                if (model.parameterSize != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      model.parameterSize!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (model.description != null && model.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(model.description!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: model.tags.take(5).map((tag) => Chip(
                label: Text(tag, style: const TextStyle(fontSize: 10)),
                padding: EdgeInsets.zero,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              )).toList(),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: onDownload,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('下载'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 推荐模型卡片（复用现有逻辑）
class _ModelCard extends ConsumerWidget {
  final ModelInfo model;
  final bool isDownloaded;
  final DownloadState? downloadState;

  const _ModelCard({
    required this.model,
    required this.isDownloaded,
    this.downloadState,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final status = downloadState?.status ?? DownloadStatus.pending;
    final progress = downloadState?.progress ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(model.name, style: theme.textTheme.titleSmall),
                ),
                Text(model.sizeLabel, style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 4),
            Text(model.description, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            if (status == DownloadStatus.downloading) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text('${(progress * 100).toStringAsFixed(2)}%', style: theme.textTheme.bodySmall),
            ] else if (status == DownloadStatus.paused) ...[
              LinearProgressIndicator(value: progress),
              const SizedBox(height: 4),
              Text('已暂停 ${(progress * 100).toStringAsFixed(2)}%', style: theme.textTheme.bodySmall),
            ] else if (isDownloaded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('已下载', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton.icon(
                    onPressed: () => _startDownload(ref),
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('下载'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startDownload(WidgetRef ref) {
    final manager = ref.read(modelManagerProvider);
    final notifier = ref.read(downloadStatesProvider.notifier);
    final taskId = DownloadStatesNotifier.makeTaskId(model.id, 'gguf');

    notifier.startDownload(taskId);
    final cancelToken = notifier.getCancelToken(taskId);
    manager.downloadModel(
      model,
      onProgress: (p) => notifier.updateProgress(taskId, p),
      cancelToken: cancelToken,
    ).then((_) {
      notifier.completeDownload(taskId);
    }).catchError((e) {
      if (e is PauseException) {
        return;
      }
      notifier.failDownload(taskId, e.toString());
    });
  }
}

/// 下载中卡片
class _DownloadingCard extends ConsumerWidget {
  final String modelId;
  final DownloadState state;

  const _DownloadingCard({
    required this.modelId,
    required this.state,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPaused = state.status == DownloadStatus.paused;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(modelId, style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: state.progress),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${(state.progress * 100).toStringAsFixed(1)}% ${isPaused ? "(已暂停)" : ""}'),
                Row(
                  children: [
                    if (isPaused)
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        onPressed: () => ref.read(downloadStatesProvider.notifier).resumeDownload(modelId),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.pause),
                        onPressed: () => ref.read(downloadStatesProvider.notifier).pauseDownload(modelId),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => ref.read(downloadStatesProvider.notifier).removeState(modelId),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 已下载模型卡片（复用现有逻辑）
class _DownloadedModelCard extends ConsumerWidget {
  final DownloadedModel model;

  const _DownloadedModelCard({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sizeMB = (model.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    final localConfig = ref.watch(localLlmConfigProvider);
    final isLoaded = localConfig.modelPath == model.modelPath;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: isLoaded
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.model_training),
        title: Text(model.id, style: theme.textTheme.bodyMedium),
        subtitle: Text(
          '$sizeMB MB',
          style: theme.textTheme.bodySmall,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLoaded)
              TextButton(
                onPressed: () {
                  ref.read(localLlmConfigProvider.notifier).update(
                    LocalLlmConfig(
                      modelPath: model.modelPath,
                      mmprojPath: model.mmprojPath,
                    ),
                  );
                },
                child: const Text('加载'),
              ),
            IconButton(
              icon: const Icon(Icons.folder_open),
              onPressed: () async {
                final manager = ref.read(modelManagerProvider);
                final result = await manager.showModelInFolder(model.id);
                if (result.type != ResultType.done) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('打开失败: ${result.message}')),
                    );
                  }
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(modelManagerProvider).deleteModel(model.id);
                // 清理该模型的所有下载状态
                final notifier = ref.read(downloadStatesProvider.notifier);
                notifier.removeState(DownloadStatesNotifier.makeTaskId(model.id, 'gguf'));
                notifier.removeState(DownloadStatesNotifier.makeTaskId(model.id, 'mmproj'));
              },
            ),
          ],
        ),
      ),
    );
  }
}
