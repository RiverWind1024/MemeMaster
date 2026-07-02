# LLM Meme Analysis 设计文档

## 概述

为 MemeManager 添加多模态 LLM 分析能力，让 LLM 直接分析 meme 图片本身（而非依赖 OCR 文本），生成可用于检索的代表性标签。

## 背景

- 现有 OCR 已能从图片文字提取标签
- 现有 LLM enricher 基于 OCR 文本做二次分析
- 新功能让 LLM 直接「看」图片，识别物体/场景/表情/情绪等非文字元素
- OCR 和 LLM vision 各自独立运行，检索时融合所有来源的 tag

## 技术选型

| 模块 | 方案 | 理由 |
|------|------|------|
| 状态管理 | Riverpod（现有） | 沿用项目已有模式 |
| 远程 LLM API | OpenAI 兼容 API（现有 OpenAiLlmService 扩展） | GPT-4o、Groq、DeepSeek、SiliconFlow 等均支持 vision |
| 本地 LLM 推理 | **llamafu**（新增依赖） | Flutter FFI 插件，基于 llama.cpp，支持 Android/iOS，GGUF 格式，内置 vision/multimodal |
| 模型格式 | GGUF | llama.cpp 标准格式，HuggingFace 大量预量化模型 |
| 持久化 | SharedPreferences（现有） | 沿用项目已有的配置持久化方案 |
| 日志 | LogService（现有） | 沿用项目已有的日志基础设施 |

## 架构

### 分层

```
┌─────────────────────────────────────────────────┐
│                  设置 UI                          │
│   LLM 模式切换 (关闭/远程/本地) + 各模式配置       │
├─────────────────────────────────────────────────┤
│              分析管线调度器                         │
│   ① 颜色提取 (已有) → ② OCR (已有) → ③ Vision LLM │
├─────────────────────────────────────────────────┤
│              LLM 服务层                            │
│   ┌──────────────────┐  ┌──────────────────┐     │
│   │ OpenAiLlmService  │  │ LocalLlmService  │     │
│   │ (远程, 扩展vision) │  │ (本地, llamafu)   │     │
│   └──────────────────┘  └──────────────────┘     │
├─────────────────────────────────────────────────┤
│              模型管理                              │
│   下载/删除/列举 GGUF 模型文件                     │
└─────────────────────────────────────────────────┘
```

### 关键模块

#### 1. LlmMode — LLM 模式枚举

```dart
enum LlmMode { off, remote, local }

// LlmConfig 扩展 mode 字段
class LlmConfig {
  final LlmMode mode;       // 新增
  final String baseUrl;     // 远程用
  final String apiKey;      // 远程用
  final String model;       // 远程用
}
```

#### 2. LocalLlmConfig — 本地模式配置（新增）

```dart
class LocalLlmConfig {
  final String? modelPath;      // GGUF 模型文件路径
  final String? mmprojPath;     // 多模态投影文件路径
  final int contextSize;        // 默认 2048
  final int threads;            // 默认 4
  final bool useGpu;            // 默认 true
}
```

#### 3. LlmMessage 支持图片（扩展）

```dart
class LlmMessage {
  final String role;
  final String content;
  final String? imageBase64;   // 新增
  
  // OpenAI vision 格式序列化
  // Ollama /api/chat images 数组格式
}
```

#### 4. VisionLlmEnricher — 多模态分析器（新增，替代现有 enricher 的纯文本方式）

```dart
class VisionLlmEnricher {
  final LlmService _llm;
  final MemeRepository _repo;
  final LogService _log;
  
  Future<void> enrich(String memeId, String imagePath);
  
  // Prompt: 分析 meme 图片，返回 JSON tags
  // { "tags": [...], "description": "..." }
  static const _systemPrompt = '你是一个表情包分析专家...';
}
```

#### 5. LocalLlmService — 本地推理实现（新增）

```dart
class LocalLlmService implements LlmService {
  Llamafu? _engine;
  
  Future<void> loadModel(LocalLlmConfig config);
  Future<void> unloadModel();
  
  // 文字模型 → complete()
  // 多模态 → multimodalComplete()
  Future<String> chat(List<LlmMessage> messages, {LlmOptions? options});
}
```

#### 6. ModelManager — 模型下载管理（新增）

```dart
class ModelManager {
  // 预设推荐模型列表
  static const recommendedModels = [
    // Qwen2-VL 2B, Moondream 2B 等
  ];
  
  Future<void> downloadModel(ModelInfo info, {void Function(double)? onProgress});
  Future<void> deleteModel(String modelId);
  List<DownloadedModel> getDownloadedModels();
  String getStoragePath();
}
```

建议首发支持的模型：

| 模型 | 大小 | 量化 | 优势 |
|------|------|------|------|
| Qwen2-VL-2B-Instruct | ~1.8 GB | Q4_K_M | 多模态能力强，中文好 |
| Moondream 2B | ~1.2 GB | Q4_K_M | 超轻量，适合低端设备 |

#### 7. 设置 UI — 扩展现有 SettingsScreen

- `LlmModeSelector`: 关闭/远程/本地 SegmentedButton
- 根据模式展开对应配置面板
- 远程：Endpoint + API Key + 模型名（TextFormField）
- 本地：模型列表（下载/删除/状态），下载进度条

#### 8. Provider 层 — 新增/改造

```dart
// LLM 模式
final llmModeProvider = NotifierProvider<LlmmModeNotifier, LlmMode>;

// 本地配置
final localLlmConfigProvider = NotifierProvider<LocalLlmConfigNotifier, LocalLlmConfig>;

// 模型管理
final modelManagerProvider = Provider<ModelManager>;

// 已下载模型列表
final downloadedModelsProvider = FutureProvider<List<DownloadedModel>>;

// 服务层改造 - 根据模式创建对应服务
final llmServiceProvider = Provider<LlmService?>((ref) {
  switch (ref.watch(llmModeProvider)) {
    case LlmMode.off: return null;
    case LlmMode.remote: return OpenAiLlmService(...);
    case LlmMode.local: return LocalLlmService(...);
  }
});
```

## 新增依赖

```yaml
dependencies:
  llamafu: ^0.1.0  # 或最新版本
  http_parser: ^4.0.0  # 图片 MIME 类型检测
```

## 数据流

### 分析管线集成（AnalysisQueueScheduler 扩展）

```
图片导入
  → 加入分析队列 (已有)
  → 颜色提取 (已有)
  → OCR 识别 → OCR tags (已有)
  → LLM Vision 分析 (新增)：
      1. 读取图片文件，转为 base64
      2. 调用 LlmService.chat()（含图片消息）
      3. 解析 JSON 响应 → tags
      4. 保存为 TagEntry(source: 'llm')
      5. 更新 Meme 分析状态
  → 分析完成
```

### 检索

搜索时查询所有 source 的 tag（现有逻辑无需变更）：
- SQL: `SELECT * FROM tags WHERE content LIKE ?` 已覆盖所有来源

## 错误处理

| 场景 | 行为 |
|------|------|
| 远程 API 不可达 | LogService 记录 error，任务标记 failed，不阻塞后续分析 |
| 本地模型未加载 | LogService 记录 warning，跳过 LLM 步骤 |
| 下载中断 | 支持断点续下（通过 HTTP Range 头） |
| JSON 解析失败 | 回退：尝试从纯文本中提取 tag，若失败则跳过 |
| 图片过大 | 压缩至 1024x1024 内再发送（节省 token + 加速） |

## 隐私与安全

- 远程模式：API Key 存储在 SharedPreferences（项目现有方式）或 FlutterSecureStorage
- 本地模式：图片数据和模型完全在设备端，无需联网
- 用户需明确开启 AI 分析（默认关闭）

## 阶段性实现

### Phase 1（当前）- 核心功能 + 安卓优先
1. LlmMode 三选一 + 配置持久化
2. VisualLlmEnricher（分析管线集成）
3. OpenAiLlmService vision 扩展（远程模式）
4. llamafu 集成（本地模式）
5. 模型下载管理（ModelManager）
6. 设置 UI 扩展
7. LogService 日志记录

### Phase 2 - 增强
1. iOS 适配（llamafu 已支持）
2. 更多模型选择（LLaVA、Gemma 3 等）
3. 批量分析时的进度通知

## 影响范围

| 文件 | 修改类型 |
|------|----------|
| `lib/core/llm/config.dart` | 扩展 LlmProviderType → LlmMode，新增 LlmConfig.mode |
| `lib/core/llm/models.dart` | LlmMessage 增加 imageBase64 字段 |
| `lib/core/llm/llm_service.dart` | 接口不变 |
| `lib/core/llm/openai_service.dart` | chat() 方法支持 vision 消息格式 |
| `lib/core/llm/ollama_service.dart` | 不变（复用 OpenAI 兼容） |
| `lib/core/llm/enricher.dart` | 新增 VisionLlmEnricher |
| **`lib/core/llm/local_service.dart`** | **新建** - LocalLlmService |
| **`lib/core/llm/model_manager.dart`** | **新建** - ModelManager |
| **`lib/core/llm/local_config.dart`** | **新建** - LocalLlmConfig |
| `lib/services/analysis_queue_scheduler.dart` | 新增 LLM Vision 分析步骤 |
| `lib/features/gallery/gallery_provider.dart` | 扩展 provider 层 |
| `lib/features/settings/settings_screen.dart` | 扩展 LLM 设置 UI |
| **`lib/features/settings/llm_settings_screen.dart`** | **新建** - 独立 LLM 设置页 |
| `pubspec.yaml` | 添加 llamafu 依赖 |
