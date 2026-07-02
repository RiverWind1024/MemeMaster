# 模型下载管理设计

## 概述

为 MemeHelper 的本地 LLM 功能实现模型下载管理：支持从 **HuggingFace** 和 **ModelScope** 双源下载 GGUF 模型文件，并提供配套的模型管理 UI。

## 核心概念

### DownloadSource 枚举

```dart
enum DownloadSource { huggingface, modelscope }
```

每个推荐模型属于一个下载源。用户通过 tab 切换源，查看该源可用的模型列表。

### ModelInfo 扩展

增加 `source` 字段，标记模型所属下载源。`ggufUrl` / `mmprojUrl` 直接指向该源的下载链接。

```dart
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final DownloadSource source;  // 新增
  final String ggufUrl;
  final String? mmprojUrl;
  final String sizeLabel;
}
```

### DownloadState

跟踪单个模型的下载进度：

```dart
enum DownloadStatus { pending, downloading, completed, failed }

class DownloadState {
  final String modelId;
  final DownloadStatus status;
  final double progress;       // 0.0 ~ 1.0
  final String? errorMessage;
}
```

## 数据模型

### ModelManager

```dart
class ModelManager {
  final String _storageDir;
  final http.Client _client;

  /// 推荐模型列表，按下载源分组
  static const Map<DownloadSource, List<ModelInfo>> recommendedModels = { ... };

  /// 断点续传下载
  Future<void> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
  });

  /// 获取已下载模型列表
  List<DownloadedModel> getDownloadedModels();

  /// 删除模型
  Future<void> deleteModel(String modelId);

  /// 存储占用
  int getStorageUsageBytes();
}
```

### 推荐模型

**HuggingFace 源：**
| 模型 ID | 名称 | 大小 |
|---------|------|------|
| qwen2-vl-2b-instruct-q4_k_m | Qwen2-VL 2B | ~1.8GB + mmproj |
| moondream-2b-q4_k_m | Moondream 2B | ~1.2GB |

**ModelScope 源：**
同模型从 ModelScope 镜像下载，URL 指向 modelscope.cn。

## 下载流程（断点续传）

```
1. 创建临时文件 {id}.gguf.download
2. HEAD 请求获取服务器文件总大小（Content-Length）
3. 若临时文件存在 → Range: bytes={localSize}-
4. 流式写入，每块回调 onProgress(current / total)
5. 下载完成 → 重命名为 {id}.gguf
6. 若有 mmproj → 同逻辑下载 mmproj-{id}.gguf
7. 失败时保留 .download 文件供下次续传
```

## Provider

```dart
// ModelManager 实例
final modelManagerProvider = Provider<ModelManager>(...);

// 下载状态跟踪
final downloadStatesProvider = StateNotifierProvider<DownloadStatesNotifier, Map<String, DownloadState>>(...);
```

`main.dart` 初始化 storageDir：
```dart
final modelsDir = Directory('${docsDir.path}/models');
if (!await modelsDir.exists()) await modelsDir.create(recursive: true);
```

## UI：模型管理页面

**路由：** `/settings/llm/model-manager`

**导航：** LLM 设置页 → 本地模式「下载推荐模型」按钮 → push 页面

**布局：**
```
AppBar: 模型管理

TabBar: [HuggingFace] [ModelScope]

推荐模型列表（当前源）：
  ┌──────────────────────────────┐
  │ 模型名              大小标签 │
  │ 描述文字                    │
  │ [下载] / [已下载] / [删除]  │
  │ 下载中: [━━━━━░░░░] 70%    │
  └──────────────────────────────┘

已下载模型（不论源，全部列出）：
  ┌──────────────────────────────┐
  │ 模型名          已加载 ✓    │
  │ 存储路径 / 下载时间          │
  │ [加载 / 删除]               │
  └──────────────────────────────┘
```

### 交互说明

- **源切换**：TabBar 切换 HuggingFace / ModelScope，下方列表跟随切换
- **下载**：点击「下载」按钮触发下载，按钮变为进度条
- **已下载**：同一模型在两个源中都有时，下载一个后另一个也标记为已下载（基于 modelId）
- **加载**：点击「加载」将模型路径写入 LocalLlmConfig，返回设置页
- **删除**：确认弹窗后删除文件，刷新列表

## 文件变更清单

| 文件 | 操作 |
|------|------|
| `lib/core/llm/model_manager.dart` | 修改：DownloadSource/DownloadState、完整 downloadModel |
| `lib/features/settings/model_manager_screen.dart` | 新建：模型管理页面 |
| `lib/features/settings/llm_settings_screen.dart` | 修改：本地模式连接真实下载入口 |
| `lib/features/gallery/gallery_provider.dart` | 修改：modelManagerProvider 初始化、downloadStatesProvider |
| `lib/router.dart` | 修改：添加 model-manager 路由 |
| `lib/main.dart` | 修改：初始化 models 目录 |

## 不做的事

- 不实现模型自动更新检查
- 不处理鉴权（公开模型无需 HF Token / ModelScope Token）
- 不实现多文件分片下载
- 下载源切换只在模型管理页面内，不污染 LLM 设置页
