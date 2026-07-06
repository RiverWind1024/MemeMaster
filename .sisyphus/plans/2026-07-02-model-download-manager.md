# 模型下载管理 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为本地 LLM 实现从 HuggingFace / ModelScope 断点续传下载 GGUF 模型，并提供完整的模型管理 UI。

**Architecture:** ModelManager 核心下载逻辑独立于 UI，通过 downloadStatesProvider 暴露下载状态；模型管理页面通过 tab 切换下载源，列表驱动下载/删除/加载操作。

**Tech Stack:** Flutter 3.x, Riverpod 2.x, GoRouter, http package (已依赖)

---

## Chunk 1: ModelManager 核心改造

### Task 1.1: 添加 DownloadSource / DownloadState / CancelToken

**Files:**
- Modify: `lib/core/llm/model_manager.dart`

- [ ] **Step 1: 在 model_manager.dart 中新增类型定义**

在文件顶部、`ModelInfo` 类的上方，添加以下枚举和类：

```dart
/// 模型下载源
enum DownloadSource { huggingface, modelscope }

/// 下载状态
enum DownloadStatus { pending, downloading, completed, failed }

/// 单个模型的下载跟踪状态
class DownloadState {
  final String modelId;
  final DownloadStatus status;
  final double progress; // 0.0 ~ 1.0
  final String? errorMessage;

  const DownloadState({
    required this.modelId,
    this.status = DownloadStatus.pending,
    this.progress = 0.0,
    this.errorMessage,
  });

  DownloadState copyWith({
    DownloadStatus? status,
    double? progress,
    String? errorMessage,
  }) {
    return DownloadState(
      modelId: modelId,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// 下载取消令牌
class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
}
```

- [ ] **Step 2: 给 ModelInfo 加 source 字段**

```dart
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final DownloadSource source; // 新增
  final String ggufUrl;
  final String? mmprojUrl;
  final String sizeLabel;

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.source, // 新增 required
    required this.ggufUrl,
    this.mmprojUrl,
    this.sizeLabel = '',
  });
}
```

- [ ] **Step 3: recommendedModels 改为 Map**

把原有的 `static const recommendedModels` 替换为：

```dart
static const Map<DownloadSource, List<ModelInfo>> recommendedModels = {
  DownloadSource.huggingface: [
    ModelInfo(
      id: 'qwen2-vl-2b-instruct-q4_k_m',
      source: DownloadSource.huggingface,
      name: 'Qwen2-VL 2B',
      description: '阿里通义多模态，中文优秀，适合手机端推理',
      ggufUrl: 'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
      mmprojUrl: 'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
      sizeLabel: '~1.8 GB',
    ),
    ModelInfo(
      id: 'moondream-2b-q4_k_m',
      source: DownloadSource.huggingface,
      name: 'Moondream 2B',
      description: '轻量多模态，专为图片描述优化',
      ggufUrl: 'https://huggingface.co/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
      sizeLabel: '~1.2 GB',
    ),
  ],
  DownloadSource.modelscope: [
    // ModelScope 同模型，URL 指向 modelscope.cn
    ModelInfo(
      id: 'qwen2-vl-2b-instruct-q4_k_m',
      source: DownloadSource.modelscope,
      name: 'Qwen2-VL 2B',
      description: '阿里通义多模态，中文优秀，适合手机端推理（ModelScope 镜像）',
      ggufUrl: 'https://modelscope.cn/models/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
      mmprojUrl: 'https://modelscope.cn/models/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
      sizeLabel: '~1.8 GB',
    ),
    ModelInfo(
      id: 'moondream-2b-q4_k_m',
      source: DownloadSource.modelscope,
      name: 'Moondream 2B',
      description: '轻量多模态，专为图片描述优化（ModelScope 镜像）',
      ggufUrl: 'https://modelscope.cn/models/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
      sizeLabel: '~1.2 GB',
    ),
  ],
};
```

- [ ] **Step 4: 实现完整 downloadModel**

替换 `downloadModel()` 存根：

```dart
/// 下载模型（带进度回调与取消支持）
Future<void> downloadModel(
  ModelInfo info, {
  void Function(double progress)? onProgress,
  CancelToken? cancelToken,
}) async {
  // 下载主模型文件
  await _downloadFile(
    url: info.ggufUrl,
    destPath: p.join(_storageDir, '${info.id}.gguf'),
    onProgress: onProgress,
    cancelToken: cancelToken,
  );

  // 下载 mmproj 文件（如果有）
  if (info.mmprojUrl != null) {
    await _downloadFile(
      url: info.mmprojUrl!,
      destPath: p.join(_storageDir, 'mmproj-${info.id}.gguf'),
      onProgress: onProgress, // 整体进度会以文件粒度变化
      cancelToken: cancelToken,
    );
  }
}

/// 单个文件的断点续传下载
Future<void> _downloadFile({
  required String url,
  required String destPath,
  void Function(double progress)? onProgress,
  CancelToken? cancelToken,
}) async {
  final tempPath = '$destPath.download';
  final tempFile = File(tempPath);

  // 检查已有临时文件大小
  int downloadedBytes = 0;
  if (await tempFile.exists()) {
    downloadedBytes = await tempFile.length();
  }

  // HEAD 请求获取总大小
  final headResp = await _client.send(Request('HEAD', Uri.parse(url)));
  final totalBytes = headResp.headers['content-length'] != null
      ? int.parse(headResp.headers['content-length']!)
      : -1;

  // 如果已下载完整，直接跳过
  if (totalBytes > 0 && downloadedBytes >= totalBytes) {
    await tempFile.rename(destPath);
    onProgress?.call(1.0);
    return;
  }

  // GET 请求 + Range 头
  final request = Request('GET', Uri.parse(url));
  if (downloadedBytes > 0) {
    request.headers['Range'] = 'bytes=$downloadedBytes-';
  }
  final response = await _client.send(request);

  // 处理响应码
  final statusCode = response.statusCode;
  if (downloadedBytes > 0 && statusCode == 206 || downloadedBytes == 0 && statusCode == 200) {
    // 正常: 206 Partial Content 或 200 (全新下载)
  } else if (downloadedBytes > 0 && statusCode == 200) {
    // 服务器不支持 Range，重新下载
    downloadedBytes = 0;
    if (await tempFile.exists()) await tempFile.delete();
  } else {
    throw HttpException('下载失败: HTTP $statusCode', uri: Uri.parse(url));
  }

  // 流式写入
  final sink = tempFile.openWrite(mode: FileMode.writeOnlyAppend);
  try {
    await for (final chunk in response.stream) {
      if (cancelToken?.isCancelled == true) {
        throw Exception('下载已取消');
      }
      sink.add(chunk);
      downloadedBytes += chunk.length;
      if (totalBytes > 0) {
        onProgress?.call(downloadedBytes / totalBytes);
      }
    }
    await sink.flush();
  } catch (e) {
    await sink.close();
    rethrow;
  }
  await sink.close();

  // 重命名完成
  if (await File(destPath).exists()) await File(destPath).delete();
  await tempFile.rename(destPath);
  onProgress?.call(1.0);
}
```

- [ ] **Step 5: 提交**

```bash
git add lib/core/llm/model_manager.dart
git commit -m "feat: 实现 ModelManager 断点续传下载与 DownloadSource 支持"
```

---

## Chunk 2: Provider 层完善

### Task 2.1: 添加 downloadStatesProvider + 修复 modelManagerProvider

**Files:**
- Modify: `lib/features/gallery/gallery_provider.dart`

- [ ] **Step 1: 在 gallery_provider.dart 中添加 downloadStatesProvider**

在 `modelManagerProvider` 定义之前或之后添加：

```dart
// ---- 模型下载状态 ----

/// 下载状态跟踪 Notifier
class DownloadStatesNotifier extends StateNotifier<Map<String, DownloadState>> {
  DownloadStatesNotifier() : super({});

  void startDownload(String modelId) {
    state = {
      ...state,
      modelId: DownloadState(modelId: modelId, status: DownloadStatus.downloading),
    };
  }

  void updateProgress(String modelId, double progress) {
    state = {
      ...state,
      modelId: state[modelId]?.copyWith(progress: progress) ??
          DownloadState(modelId: modelId, status: DownloadStatus.downloading, progress: progress),
    };
  }

  void completeDownload(String modelId) {
    state = {
      ...state,
      modelId: state[modelId]?.copyWith(status: DownloadStatus.completed, progress: 1.0) ??
          DownloadState(modelId: modelId, status: DownloadStatus.completed, progress: 1.0),
    };
  }

  void failDownload(String modelId, String error) {
    state = {
      ...state,
      modelId: state[modelId]?.copyWith(status: DownloadStatus.failed, errorMessage: error) ??
          DownloadState(modelId: modelId, status: DownloadStatus.failed, errorMessage: error),
    };
  }

  void removeState(String modelId) {
    final map = Map<String, DownloadState>.from(state);
    map.remove(modelId);
    state = map;
  }
}

final downloadStatesProvider = StateNotifierProvider<DownloadStatesNotifier, Map<String, DownloadState>>((ref) {
  return DownloadStatesNotifier();
});
```

- [ ] **Step 2: 修复 modelManagerProvider**

将现有的 `modelManagerProvider`（现在抛 UnimplementedError）改为接受外部参数。但 Riverpod 的 Provider 不支持参数传递，所以需要用 `main.dart` 覆盖。

改为：

```dart
final storageDirProvider = Provider<String>((ref) {
  throw UnimplementedError('storageDirProvider 需要在 main.dart 中覆盖');
});

final modelManagerProvider = Provider<ModelManager>((ref) {
  final dir = ref.watch(storageDirProvider);
  return ModelManager(storageDir: dir);
});
```

这样 `main.dart` 只需 override `storageDirProvider` 即可。

- [ ] **Step 3: 提交**

```bash
git add lib/features/gallery/gallery_provider.dart
git commit -m "feat: 添加 downloadStatesProvider，修复 modelManagerProvider"
```

### Task 2.2: main.dart 初始化 models 目录

**Files:**
- Modify: `lib/main.dart`

- [ ] **Step 1: 在 main 中初始化目录并 override Provider**

修改 `main.dart`，在 `runApp` 之前添加 models 目录初始化，并通过 `ProviderScope.overrides` 注入：

```dart
import 'dart:io';
// ... 已有 import

void main() async {
  // ... 已有初始化代码 ...

  final docsDir = await getApplicationDocumentsDirectory();
  final modelsDir = Directory('${docsDir.path}/models');
  if (!await modelsDir.exists()) {
    await modelsDir.create(recursive: true);
  }
  debugPrint('[Startup] models dir: ${modelsDir.path}');

  // ... 已有代码 ...

  runApp(
    ProviderScope(
      overrides: [
        storageDirProvider.overrideWithValue(modelsDir.path),
      ],
      child: MemeManagerApp(prefs: prefs),
    ),
  );
}
```

注意：需要确认 `MemeManagerApp` 当前是否已经被 `ProviderScope` 包裹。如果 `app.dart` 中已经有 `ProviderScope`，则需要在外部再包一层或移到 main 中。

- [ ] **Step 2: 提交**

```bash
git add lib/main.dart
git commit -m "feat: 初始化 models 目录，注入 storageDirProvider"
```

---

## Chunk 3: 模型管理 UI

### Task 3.1: 创建模型管理页面

**Files:**
- Create: `lib/features/settings/model_manager_screen.dart`

- [ ] **Step 1: 创建页面骨架**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/llm/model_manager.dart';
import '../../core/llm/local_config.dart';
import '../gallery/gallery_provider.dart';

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
    final manager = ref.watch(modelManagerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('模型管理'),
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
```

- [ ] **Step 2: 创建 ModelSourceTab 组件**

```dart
class _ModelSourceTab extends ConsumerWidget {
  final DownloadSource source;

  const _ModelSourceTab({required this.source});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(modelManagerProvider);
    final models = ModelManager.recommendedModels[source] ?? [];
    final downloaded = manager.getDownloadedModels();
    final downloadStates = ref.watch(downloadStatesProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 推荐模型列表
        Text('推荐模型', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...models.map((model) => _ModelCard(
          model: model,
          downloaded: downloaded.any((d) => d.id == model.id),
          downloadState: downloadStates[model.id],
        )),
        const SizedBox(height: 24),

        // 已下载模型
        Text('已下载模型', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (downloaded.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Text(
                  '暂无已下载的模型',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
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
```

- [ ] **Step 3: 创建 ModelCard（推荐模型项）**

```dart
class _ModelCard extends ConsumerWidget {
  final ModelInfo model;
  final bool downloaded;
  final DownloadState? downloadState;

  const _ModelCard({
    required this.model,
    required this.downloaded,
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
            ] else if (downloaded) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text('已下载', style: theme.textTheme.bodySmall?.copyWith(color: Colors.green)),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => _loadModel(ref),
                    icon: const Icon(Icons.play_arrow, size: 16),
                    label: const Text('加载'),
                  ),
                  TextButton.icon(
                    onPressed: () => _deleteModel(ref),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('删除'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
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
                      child: Text('下载失败', style: theme.textTheme.bodySmall?.copyWith(color: Colors.red)),
                    ),
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
          SnackBar(content: Text('${model.name} 下载完成')),
        );
      }
    } catch (e) {
      notifier.failDownload(model.id, e.toString());
      if (ref.context.mounted) {
        ScaffoldMessenger.of(ref.context).showSnackBar(
          SnackBar(content: Text('下载失败: $e')),
        );
      }
    }
  }

  void _loadModel(WidgetRef ref) {
    final manager = ref.read(modelManagerProvider);
    final downloaded = manager.getDownloadedModels().firstWhere((d) => d.id == model.id);
    ref.read(localLlmConfigProvider.notifier).update(
      LocalLlmConfig(
        modelPath: downloaded.modelPath,
        mmprojPath: downloaded.mmprojPath,
      ),
    );
    if (ref.context.mounted) {
      ScaffoldMessenger.of(ref.context).showSnackBar(
        const SnackBar(content: Text('模型已加载，请切换至本地模式使用')),
      );
    }
  }

  void _deleteModel(WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: ref.context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认删除'),
        content: Text('确定要删除 ${model.name} 吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除')),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(modelManagerProvider).deleteModel(model.id);
      ref.read(downloadStatesProvider.notifier).removeState(model.id);
      if (ref.context.mounted) {
        ref.context.unmount(); // 触发刷新
      }
    }
  }
}
```

- [ ] **Step 4: 创建 _DownloadedModelCard**

```dart
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
        subtitle: Text('${sizeMB} MB • ${model.downloadedAt.toString().substring(0, 10)}',
          style: theme.textTheme.bodySmall),
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
                    const SnackBar(content: Text('模型已加载')),
                  );
                },
                child: const Text('加载'),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await ref.read(modelManagerProvider).deleteModel(model.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${model.id} 已删除')),
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
```

- [ ] **Step 5: 提交**

```bash
git add lib/features/settings/model_manager_screen.dart
git commit -m "feat: 创建模型管理页面（双源切换 + 下载/加载/删除）"
```

---

## Chunk 4: 集成与路由

### Task 4.1: 更新 LLM 设置页 + 路由

**Files:**
- Modify: `lib/features/settings/llm_settings_screen.dart`
- Modify: `lib/router.dart`

- [ ] **Step 1: 更新 LLM 设置页的本地模式**

在 `llm_settings_screen.dart` 的本地模式区域（`if (mode == LlmMode.local)`），修改 "暂无已下载模型" 分支中的 OutlinedButton：

```dart
// 替换原来的 OutlinedButton
OutlinedButton.icon(
  onPressed: () => context.push('/settings/llm/model-manager'),
  icon: const Icon(Icons.open_in_new),
  label: const Text('下载推荐模型'),
),
```

同时修改已加载模型区域的 ListTile，将移除模型的按钮改为导航到模型管理：

```dart
// 修改已加载模型行的 trailing
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
```

- [ ] **Step 2: 添加路由**

在 `router.dart` 中，找到路由定义并添加：

```dart
// 在 /settings/llm 路由之后或附近
GoRoute(
  path: 'model-manager',
  name: 'model-manager',
  builder: (context, state) => const ModelManagerScreen(),
),
```

导入：
```dart
import '../features/settings/model_manager_screen.dart';
```

- [ ] **Step 3: 提交**

```bash
git add lib/features/settings/llm_settings_screen.dart lib/router.dart
git commit -m "feat: 集成模型管理页面入口和路由"
```

---

## Chunk 5: 验证

### Task 5.1: 编译检查

- [ ] **Step 1: 运行 dart analyze**

```bash
flutter pub get && dart analyze lib/
```

确认零新增 error。所有 error 应只来自 `test/` 目录的预存问题。

- [ ] **Step 2: 如有错误，修复**

修复编译错误后提交。
