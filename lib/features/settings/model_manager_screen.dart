import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/local_config.dart';
import '../../core/llm/model_manager.dart';
import '../gallery/gallery_provider.dart';
import '../../l10n/app_localizations.dart';

class ModelManagerScreen extends ConsumerStatefulWidget {
  const ModelManagerScreen({super.key});

  @override
  ConsumerState<ModelManagerScreen> createState() => _ModelManagerScreenState();
}

class _ModelManagerScreenState extends ConsumerState<ModelManagerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.of(context).modelManager),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'HuggingFace'),
            Tab(text: 'ModelScope'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ModelSourceTab(source: DownloadSource.huggingface),
          _ModelSourceTab(source: DownloadSource.modelscope),
        ],
      ),
    );
  }
}

/// 单个下载源的模型列表
class _ModelSourceTab extends ConsumerWidget {
  final DownloadSource source;

  const _ModelSourceTab({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(modelManagerProvider);
    final models = ModelManager.recommendedModels[source] ?? [];
    final downloaded = manager.getDownloadedModels();
    final downloadStates = ref.watch(downloadStatesProvider);
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 推荐模型列表
        Text(S.of(context).recommendedModels, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (models.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  S.of(context).noRecommendedModels,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ...models.map((model) => _ModelCard(
                model: model,
                isDownloaded: downloaded.any((d) => d.id == model.id),
                downloadState: downloadStates[model.id],
              )),
        const SizedBox(height: 24),

        // 已下载模型
        Text(S.of(context).downloadedModels, style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (downloaded.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  S.of(context).noDownloadedModels,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          )
        else
          ...downloaded.map((d) => _DownloadedModelCard(model: d)),
      ],
    );
  }
}

/// 推荐模型卡片
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
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall),
            ] else if (isDownloaded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(S.of(context).downloaded,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.green)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _loadModel(ref),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: Text(S.of(context).loadModel),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteModel(ref),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: Text(S.of(context).deleteModel),
                    style:
                        TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            ] else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (downloadState?.status == DownloadStatus.failed)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Text(S.of(context).downloadFailed,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: Colors.red)),
                    ),
                  FilledButton.icon(
                    onPressed: () => _startDownload(ref),
                    icon: const Icon(Icons.download, size: 18),
                    label: Text(S.of(context).download),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _startDownload(WidgetRef ref) async {
    final manager = ref.read(modelManagerProvider);
    final notifier = ref.read(downloadStatesProvider.notifier);

    notifier.startDownload(model.id);
    try {
      await manager.downloadModel(
        model,
        onProgress: (p) => notifier.updateProgress(model.id, p),
      );
      notifier.completeDownload(model.id);
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text(S.of(context).modelDownloadComplete(model.name))),
        );
      }
    } catch (e) {
      notifier.failDownload(model.id, e.toString());
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text(S.of(context).downloadFailedWithError(e.toString()))),
        );
      }
    }
  }

  void _loadModel(WidgetRef ref) {
    final manager = ref.read(modelManagerProvider);
    final downloaded =
        manager.getDownloadedModels().firstWhere((d) => d.id == model.id);
    ref.read(localLlmConfigProvider.notifier).update(
          LocalLlmConfig(
            modelPath: downloaded.modelPath,
            mmprojPath: downloaded.mmprojPath,
          ),
        );
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        SnackBar(content: Text(S.of(context).modelLoadedSwitchToLocal)),
      );
    }
  }

  void _deleteModel(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ref.context,
      builder: (ctx) => AlertDialog(
        title: Text(S.of(context).confirmDelete),
        content: Text(S.of(context).confirmDeleteModel(model.name)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(S.of(context).cancel)),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(S.of(context).delete)),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(modelManagerProvider).deleteModel(model.id);
      ref.read(downloadStatesProvider.notifier).removeState(model.id);
    }
  }
}

/// 已下载模型卡片
class _DownloadedModelCard extends ConsumerWidget {
  final DownloadedModel model;

  const _DownloadedModelCard({required this.model});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sizeMB =
        (model.fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
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
          '$sizeMB MB  ●  ${model.downloadedAt.toString().substring(0, 10)}',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).modelLoaded)),
                  );
                },
                child: Text(S.of(context).loadModel),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref
                    .read(modelManagerProvider)
                    .deleteModel(model.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(S.of(context).modelDeleted(model.id))),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
