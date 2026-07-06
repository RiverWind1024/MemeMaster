# LLM 多模态视觉分析 — 实现计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 MemeManager 添加多模态 LLM 分析能力，支持远程 API（OpenAI 兼容）和本地 Llama.cpp（llamafu）两种模式，直接分析 meme 图片生成标签。

**Architecture:** 扩展现有 LLM 基础设施（LlmService/LlmConfig/LlmMessage），新增 VisionLlmEnricher 替代现有的纯文本 enricher。分析管线中新增视觉分析步骤，与 OCR 并行运行。

**Tech Stack:** Flutter 3.x, Riverpod 2.x, freezed, llm_service(已有), llamafu(新增)

**Reference:** `docs/superpowers/specs/2026-07-02-llm-meme-analysis-design.md`

---

### Chunk 1: Config & Model 扩展

#### Task 1.1: 新增 LlmMode 枚举，扩展 LlmConfig

**Files:**
- Modify: `lib/core/llm/config.dart`
- Modify: `lib/core/models/analysis_pipeline_config.dart`

- [ ] **Step 1: 在 config.dart 中添加 LlmMode 枚举，扩展 LlmConfig 加 mode 字段**

```dart
// LlmMode 枚举
enum LlmMode { off, remote, local }

// LlmConfig 扩展
class LlmConfig {
  final LlmMode mode;            // 新增：模式选择
  final LlmProviderType provider; // 远程模式下的供应商
  final String baseUrl;
  final String apiKey;
  final String model;

  // toJson/fromJson 增加 mode 序列化
  Map<String, dynamic> toJson() => {
        'mode': mode.name,
        'provider': provider.name,
        'baseUrl': baseUrl,
        'apiKey': apiKey,
        'model': model,
      };

  factory LlmConfig.fromJson(Map<String, dynamic> json) => LlmConfig(
        mode: LlmMode.values.byName(json['mode'] as String? ?? 'off'),
        provider:
            LlmProviderType.values.byName(json['provider'] as String),
        baseUrl: json['baseUrl'] as String,
        apiKey: json['apiKey'] as String? ?? '',
        model: json['model'] as String,
      );

  // copyWith 增加 mode 参数
  LlmConfig copyWith({
    LlmMode? mode,
    LlmProviderType? provider,
    String? baseUrl,
    String? apiKey,
    String? model,
  }) {
    return LlmConfig(
      mode: mode ?? this.mode,
      provider: provider ?? this.provider,
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
    );
  }

  const LlmConfig({
    this.mode = LlmMode.off,
    this.provider = LlmProviderType.ollama,
    this.baseUrl = 'http://localhost:11434',
    this.apiKey = '',
    this.model = 'llama3.2',
  });
}
```

- [ ] **Step 2: 在 AnalysisPipelineConfig 中将 llmEnabled 替换为 llmMode**

`lib/core/models/analysis_pipeline_config.dart`:
```dart
// 替换:
@Default(false) bool llmEnabled,
// 为:
@Default(LlmMode.off) LlmMode llmMode,
```

需要 import `'../llm/config.dart'`。

- [ ] **Step 3: 验证 LSP 无错误**

Run: `lsp_diagnostics filePath="lib/core/llm/config.dart"`
Run: `lsp_diagnostics filePath="lib/core/models/analysis_pipeline_config.dart"`

- [ ] **Step 4: Commit**

```bash
git add lib/core/llm/config.dart lib/core/models/
git commit -m "feat: 添加 LlmMode 模式枚举，扩展 LlmConfig 和 AnalysisPipelineConfig"
```

#### Task 1.2: 新增 LocalLlmConfig 模型

**Files:**
- Create: `lib/core/llm/local_config.dart`

- [ ] **Step 1: 创建 LocalLlmConfig**

```dart
/// 本地 LLM 模型配置
class LocalLlmConfig {
  /// GGUF 模型文件路径
  final String? modelPath;

  /// 多模态投影文件路径（如 Qwen2-VL 的 mmproj-qwen2-vl-prm.gguf）
  final String? mmprojPath;

  /// 上下文长度
  final int contextSize;

  /// 推理线程数
  final int threads;

  /// 是否启用 GPU 加速
  final bool useGpu;

  const LocalLlmConfig({
    this.modelPath,
    this.mmprojPath,
    this.contextSize = 2048,
    this.threads = 4,
    this.useGpu = true,
  });

  Map<String, dynamic> toJson() => {
        'modelPath': modelPath,
        'mmprojPath': mmprojPath,
        'contextSize': contextSize,
        'threads': threads,
        'useGpu': useGpu,
      };

  factory LocalLlmConfig.fromJson(Map<String, dynamic> json) =>
      LocalLlmConfig(
        modelPath: json['modelPath'] as String?,
        mmprojPath: json['mmprojPath'] as String?,
        contextSize: json['contextSize'] as int? ?? 2048,
        threads: json['threads'] as int? ?? 4,
        useGpu: json['useGpu'] as bool? ?? true,
      );

  LocalLlmConfig copyWith({
    String? modelPath,
    String? mmprojPath,
    int? contextSize,
    int? threads,
    bool? useGpu,
  }) {
    return LocalLlmConfig(
      modelPath: modelPath ?? this.modelPath,
      mmprojPath: mmprojPath ?? this.mmprojPath,
      contextSize: contextSize ?? this.contextSize,
      threads: threads ?? this.threads,
      useGpu: useGpu ?? this.useGpu,
    );
  }
}
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/local_config.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/local_config.dart
git commit -m "feat: 添加 LocalLlmConfig 模型"
```

#### Task 1.3: LlmMessage 支持图片（imageBase64）

**Files:**
- Modify: `lib/core/llm/models.dart`

- [ ] **Step 1: 在 LlmMessage 中增加 imageBase64 字段**

```dart
class LlmMessage {
  final String role;
  final String content;
  final String? imageBase64; // 新增

  const LlmMessage({
    required this.role,
    required this.content,
    this.imageBase64,
  });

  // 为了兼容现有序列化，imageBase64 在 toJson 中不序列化
  // 由 OpenAiLlmService 等具体实现决定如何发送
  Map<String, String> toJson() => {'role': role, 'content': content};
}
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/models.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/models.dart
git commit -m "feat: LlmMessage 支持 imageBase64 字段"
```

---

### Chunk 2: LLM 服务扩展

#### Task 2.1: OpenAiLlmService 支持 vision 多模态消息

**Files:**
- Modify: `lib/core/llm/openai_service.dart`

- [ ] **Step 1: 在 OpenAiLlmService.chat() 中处理含图片的消息**

改 `_buildRequestBody` 逻辑（或直接在 `chat()` 方法中处理）：

```dart
// 在 chat() 方法中，构建 body 时检查 messages 中是否含 imageBase64
List<Map<String, dynamic>> _buildMessages(List<LlmMessage> messages) {
  return messages.map((msg) {
    if (msg.imageBase64 != null) {
      return {
        'role': msg.role,
        'content': [
          {'type': 'text', 'text': msg.content},
          {
            'type': 'image_url',
            'image_url': {
              'url': 'data:image/jpeg;base64,${msg.imageBase64}',
            },
          },
        ],
      };
    }
    return msg.toJson();
  }).toList();
}
```

然后在 `chat()` 中将 `messages.map((m) => m.toJson())` 替换为 `_buildMessages(messages)`。

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/openai_service.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/openai_service.dart
git commit -m "feat: OpenAiLlmService 支持 vision 多模态消息"
```

#### Task 2.2: 创建 LocalLlmService（基础实现）

**Files:**
- Create: `lib/core/llm/local_service.dart`

- [ ] **Step 1: 创建 LocalLlmService**

```dart
import 'llm_service.dart';
import 'local_config.dart';
import 'models.dart';

/// 本地 LLM 推理服务（基于 llamafu / llama.cpp）
///
/// 支持纯文本和 vision 多模态模型。
/// 模型通过 ModelManager 下载后加载。
class LocalLlmService implements LlmService {
  final LocalLlmConfig _config;
  // llamafu engine 实例——延迟初始化
  // Llamafu? _engine;

  LocalLlmService({required LocalLlmConfig config}) : _config = config;

  @override
  bool get isAvailable => _config.modelPath != null;

  @override
  String get modelName {
    final path = _config.modelPath;
    if (path == null) return 'none';
    return path.split('/').last.replaceAll('.gguf', '');
  }

  @override
  Future<String> complete(
    String prompt, {
    LlmOptions? options,
  }) async {
    return chat(
      [LlmMessage(role: 'user', content: prompt)],
      options: options,
    );
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  }) async {
    // TODO: 集成 llamafu 后实现真实推理
    // 1. 按需加载 _engine
    // 2. 根据是否有图片决定使用 multimodalComplete 或 complete
    // 3. 解析流式/非流式输出
    throw UnimplementedError('本地推理将在 llamafu 集成后实现');
  }

  @override
  void dispose() {
    // TODO: 释放 llamafu engine
    // _engine?.close();
  }
}
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/local_service.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/local_service.dart
git commit -m "feat: 添加 LocalLlmService 基础骨架"
```

#### Task 2.3: 创建 ModelManager

**Files:**
- Create: `lib/core/llm/model_manager.dart`

- [ ] **Step 1: 创建 ModelManager 类**

```dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// 模型信息
class ModelInfo {
  final String id;
  final String name;
  final String description;
  final String ggufUrl;
  final String? mmprojUrl;
  final String sizeLabel; // 人类可读大小

  const ModelInfo({
    required this.id,
    required this.name,
    required this.description,
    required this.ggufUrl,
    this.mmprojUrl,
    this.sizeLabel = '',
  });
}

/// 已下载的模型
class DownloadedModel {
  final String id;
  final String modelPath;
  final String? mmprojPath;
  final int fileSizeBytes;
  final DateTime downloadedAt;

  const DownloadedModel({
    required this.id,
    required this.modelPath,
    this.mmprojPath,
    required this.fileSizeBytes,
    required this.downloadedAt,
  });
}

/// LLM 模型下载管理
///
/// 管理 GGUF 模型的下载、删除、列举。
/// 使用 HTTP Range 请求支持断点续传。
class ModelManager {
  final String _storageDir;
  final http.Client _client;

  ModelManager({required String storageDir, http.Client? client})
      : _storageDir = storageDir,
        _client = client ?? http.Client();

  /// 预设推荐模型列表
  static const recommendedModels = [
    ModelInfo(
      id: 'qwen2-vl-2b-instruct-q4_k_m',
      name: 'Qwen2-VL 2B',
      description: '阿里通义多模态，中文优秀，适合手机端推理',
      ggufUrl:
          'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/qwen2-vl-2b-instruct-q4_k_m.gguf',
      mmprojUrl:
          'https://huggingface.co/Qwen/Qwen2-VL-2B-Instruct-GGUF/resolve/main/mmproj-qwen2-vl-2b-instruct-f16.gguf',
      sizeLabel: '~1.8 GB',
    ),
    ModelInfo(
      id: 'moondream-2b-q4_k_m',
      name: 'Moondream 2B',
      description: '轻量多模态，专为图片描述优化',
      ggufUrl:
          'https://huggingface.co/vikhyatk/moondream2-GGUF/resolve/main/moondream2-q4_k_m.gguf',
      sizeLabel: '~1.2 GB',
    ),
  ];

  /// 模型存储目录
  String get storageDir => _storageDir;

  /// 下载模型（带进度回调）
  Future<void> downloadModel(
    ModelInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final modelPath = p.join(_storageDir, '${info.id}.gguf');
    // TODO: 实现断点续传下载
    // 1. 检查部分下载
    // 2. HTTP GET with Range header
    // 3. 流式写入文件，回调进度
    // 4. 下载 mmproj（如果有）
    throw UnimplementedError('模型下载将在后续实现');
  }

  /// 获取已下载的模型列表
  List<DownloadedModel> getDownloadedModels() {
    final dir = Directory(_storageDir);
    if (!dir.existsSync()) return [];

    return dir.listSync().whereType<File>().where((f) {
      return f.path.endsWith('.gguf');
    }).map((f) {
      final name = p.basenameWithoutExtension(f.path);
      final mmproj = File(p.join(_storageDir, 'mmproj-$name.gguf'));
      return DownloadedModel(
        id: name,
        modelPath: f.path,
        mmprojPath: mmproj.existsSync() ? mmproj.path : null,
        fileSizeBytes: f.lengthSync(),
        downloadedAt: f.lastModifiedSync(),
      );
    }).toList();
  }

  /// 删除模型
  Future<void> deleteModel(String modelId) async {
    final modelFile = File(p.join(_storageDir, '$modelId.gguf'));
    if (await modelFile.exists()) await modelFile.delete();

    final mmprojFile = File(p.join(_storageDir, 'mmproj-$modelId.gguf'));
    if (await mmprojFile.exists()) await mmprojFile.delete();
  }

  /// 获取存储占用（字节）
  int getStorageUsageBytes() {
    return getDownloadedModels()
        .fold<int>(0, (sum, m) => sum + m.fileSizeBytes);
  }

  void dispose() {
    _client.close();
  }
}
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/model_manager.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/model_manager.dart
git commit -m "feat: 添加 ModelManager 模型下载管理"
```

---

### Chunk 3: Vision Enricher + 管线集成

#### Task 3.1: 创建 VisionLlmEnricher

**Files:**
- Create: `lib/core/llm/vision_enricher.dart`
- Note: 现有的 `lib/core/llm/enricher.dart` 保留不动（可后续删除或移作参考）

- [ ] **Step 1: 创建 VisionLlmEnricher**

```dart
import 'dart:convert';
import 'dart:io';

import '../database/database.dart';
import '../repositories/meme_repository.dart';
import 'config.dart';
import 'llm_service.dart';
import 'models.dart';

/// 多模态 LLM 驱动的图片标签生成器
///
/// 直接分析图片内容（而非 OCR 文本），识别物体/场景/表情/情绪等。
/// 生成 TagEntry(source: 'llm') 标签和 Meme.description。
class VisionLlmEnricher {
  final LlmService _llm;
  final MemeRepository _repo;
  final LogService _log;

  /// 图片最大边长（超过此尺寸会被压缩以节省 token）
  static const int _maxImageDimension = 1024;

  const VisionLlmEnricher({
    required LlmService llm,
    required MemeRepository repo,
    required LogService log,
  })  : _llm = llm,
        _repo = repo,
        _log = log;

  /// 对单张 meme 执行多模态分析
  Future<void> enrich(String memeId, String imagePath) async {
    if (!_llm.isAvailable) {
      _log.warning('VisionLLM', 'LLM 不可用，跳过分析');
      return;
    }

    _log.info('VisionLLM', '开始多模态分析: $memeId');

    try {
      // 1. 读取图片并转 base64
      final imageBytes = await _readAndResizeImage(imagePath);
      final base64Image = base64Encode(imageBytes);
      _log.info('VisionLLM', '图片 base64: ${base64Image.length} 字节');

      // 2. 调用多模态 LLM
      final result = await _analyzeImage(base64Image);

      if (result == null) {
        _log.warning('VisionLLM', 'LLM 返回空结果');
        return;
      }

      // 3. 保存标签
      if (result.tags.isNotEmpty) {
        final tagEntries = result.tags.map((tag) => TagEntry(
              id: '${memeId}_llm_${tag.hashCode}',
              memeId: memeId,
              content: tag,
              source: 'llm',
              confidence: 0.7,
            )).toList();
        await _repo.saveTags(tagEntries);
        _log.info('VisionLLM', '保存 ${tagEntries.length} 个标签: ${result.tags.join(", ")}');
      }

      // 4. 保存描述
      if (result.description.isNotEmpty) {
        await _repo.updateDescription(memeId, result.description);
        _log.info('VisionLLM', '保存描述: ${result.description}');
      }
    } catch (e) {
      _log.error('VisionLLM', '多模态分析失败: $e');
    }
  }

  Future<_AnalysisResult?> _analyzeImage(String base64Image) async {
    final messages = [
      LlmMessage(
        role: 'system',
        content: _systemPrompt,
      ),
      LlmMessage(
        role: 'user',
        content: _userPrompt,
        imageBase64: base64Image,
      ),
    ];

    final response = await _llm.chat(
      messages,
      options: const LlmOptions(temperature: 0.3, maxTokens: 256),
    );

    return _parseResponse(response);
  }

  _AnalysisResult? _parseResponse(String raw) {
    try {
      // 尝试解析 JSON
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final tags = (json['tags'] as List?)
              ?.map((e) => e.toString().trim())
              .where((t) => t.length >= 2 && t.length <= 20)
              .toList() ??
          [];
      final description = (json['description'] as String?)?.trim() ?? '';
      return _AnalysisResult(tags: tags, description: description);
    } catch (_) {
      // JSON 解析失败，回退：从纯文本中提取逗号分隔的标签
      _log.warning('VisionLLM', 'JSON 解析失败，尝试回退解析: $raw');
      final tags = raw
          .split(RegExp(r'[,，、\n]+'))
          .map((w) => w.trim())
          .where((w) => w.length >= 2 && w.length <= 20)
          .toList();
      return tags.isNotEmpty
          ? _AnalysisResult(tags: tags, description: '')
          : null;
    }
  }

  Future<Uint8List> _readAndResizeImage(String imagePath) async {
    final file = File(imagePath);
    final bytes = await file.readAsBytes();

    // 如果图片过大，简单压缩（后续可用 image 库 resize）
    // 目前仅做尺寸检查，超过阈值才压缩
    if (bytes.length > 1024 * 1024) {
      _log.info('VisionLLM', '图片较大 (${bytes.length} 字节)，建议压缩后发送');
    }
    return bytes;
  }

  static const _systemPrompt = '''
你是一个表情包分析专家。请分析这张图片，返回 JSON 格式的分析结果。

要求：
- 标签用中文，每个 2-10 字
- 标签需反映图片的核心内容，如：物体、场景、人物表情、情绪、meme 模板类型
- 标签数量 3-8 个
- 描述用一句话概括，10 字以内
- 只返回 JSON，不要多余文字

输出格式：
{"tags": ["标签1", "标签2"], "description": "一句话描述"}
''';

  static const _userPrompt = '请分析这张表情包图片：';
}

class _AnalysisResult {
  final List<String> tags;
  final String description;
  const _AnalysisResult({required this.tags, required this.description});
}
```

Note: 需要 import `dart:typed_data` 和 `log_service.dart`。

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/core/llm/vision_enricher.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/core/llm/vision_enricher.dart
git commit -m "feat: 添加 VisionLlmEnricher 多模态分析器"
```

#### Task 3.2: 集成到 AnalysisQueueScheduler

**Files:**
- Modify: `lib/services/analysis_queue_scheduler.dart`

- [ ] **Step 1: 在调度器中添加 vision LLM 分析步骤**

```dart
// 1. 导入 VisionLlmEnricher
import '../core/llm/vision_enricher.dart';

// 2. 新增字段
VisionLlmEnricher? _visionEnricher;

// 3. 新增 setter
void setVisionEnricher(VisionLlmEnricher enricher) {
  _visionEnricher = enricher;
}

// 4. 在 _processJob 中，OCR 完成后加入视觉分析步骤
// 在 _runLlmEnrichment 调用之后（或替换之）：
Future<void> _runVisionLlm(String memeId, String imagePath) async {
  final enricher = _visionEnricher;
  if (enricher == null) {
    _log.info('VisionLLM', '未设置 VisionEnricher，跳过');
    return;
  }
  await enricher.enrich(memeId, imagePath);
}
```

修改 `_processJob`：在 OCR 之后、LLM enricher 之前（或之后）添加视觉分析调用：

```dart
// 在 _processJob 中 OCR 之后：
if (ocrText != null) {
  // ... 现有 OCR 标签 + 旧 enricher（基于 OCR 文本）
  // ... 这段保持不变
}

// 新增：始终执行视觉分析（不管是否 OCR 有文字）
// 因为视觉分析不依赖 OCR
await _runVisionLlm(job.memeId, imagePath);
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/services/analysis_queue_scheduler.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/services/analysis_queue_scheduler.dart
git commit -m "feat: 分析管线集成 VisionLlmEnricher"
```

---

### Chunk 4: Provider 层改造

#### Task 4.1: 扩展 Provider（llmMode, localLlmConfig, visionEnricher, modelManager）

**Files:**
- Modify: `lib/features/gallery/gallery_provider.dart`

- [ ] **Step 1: 添加 LlmMode 相关 Provider**

```dart
// 导入新增文件
import '../../core/llm/local_config.dart';
import '../../core/llm/local_service.dart';
import '../../core/llm/model_manager.dart';
import '../../core/llm/vision_enricher.dart';

// ---- LLM Mode ----

class LlmModeNotifier extends Notifier<LlmMode> {
  @override
  LlmMode build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final stored = prefs.getString('llm_mode');
      if (stored != null) return LlmMode.values.byName(stored);
    } catch (_) {}
    return LlmMode.off;
  }

  void setMode(LlmMode mode) {
    state = mode;
    try {
      ref.read(sharedPreferencesProvider).setString('llm_mode', mode.name);
    } catch (_) {}
  }
}

final llmModeProvider =
    NotifierProvider<LlmModeNotifier, LlmMode>(LlmModeNotifier.new);

// ---- 本地 LLM 配置 ----

class LocalLlmConfigNotifier extends Notifier<LocalLlmConfig> {
  @override
  LocalLlmConfig build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final jsonStr = prefs.getString('local_llm_config');
      if (jsonStr != null) {
        return LocalLlmConfig.fromJson(
            jsonDecode(jsonStr) as Map<String, dynamic>);
      }
    } catch (_) {}
    return const LocalLlmConfig();
  }

  void update(LocalLlmConfig config) {
    state = config;
    try {
      ref.read(sharedPreferencesProvider)
          .setString('local_llm_config', jsonEncode(config.toJson()));
    } catch (_) {}
  }
}

final localLlmConfigProvider =
    NotifierProvider<LocalLlmConfigNotifier, LocalLlmConfig>(
  LocalLlmConfigNotifier.new,
);

// ---- LLM 服务（按模式创建） ----

final llmServiceProvider = Provider<LlmService?>((ref) {
  final mode = ref.watch(llmModeProvider);
  switch (mode) {
    case LlmMode.off:
      return null;
    case LlmMode.remote:
      final config = ref.watch(llmConfigProvider);
      switch (config.provider) {
        case LlmProviderType.openai:
          return OpenAiLlmService(
            baseUrl: config.baseUrl,
            apiKey: config.apiKey,
            model: config.model,
          );
        case LlmProviderType.ollama:
          return OllamaLlmService(
            baseUrl: config.baseUrl,
            model: config.model,
          );
      }
    case LlmMode.local:
      final localConfig = ref.watch(localLlmConfigProvider);
      return LocalLlmService(config: localConfig);
  }
});

// ---- Vision Enricher ----

final visionEnricherProvider = Provider<VisionLlmEnricher?>((ref) {
  final llm = ref.watch(llmServiceProvider);
  final repo = ref.watch(memeRepositoryProvider);
  final log = ref.watch(logServiceProvider);
  if (llm == null || !llm.isAvailable) return null;
  return VisionLlmEnricher(llm: llm, repo: repo, log: log);
});

// ---- Model Manager ----

final modelManagerProvider = Provider<ModelManager>((ref) {
  // 使用应用文档目录下的 models/ 子目录
  // 实际路径在 main.dart 中初始化
  throw UnimplementedError('ModelManager 需要在 main.dart 中初始化存储路径');
});
```

- [ ] **Step 2: 修改 analysisSchedulerProvider 以使用 visionEnricher**

```dart
// 在 analysisSchedulerProvider 中：
final visionEnricher = ref.watch(visionEnricherProvider);
if (visionEnricher != null) {
  scheduler.setVisionEnricher(visionEnricher);
}
```

- [ ] **Step 3: 清理旧的 LlmEnabledNotifier（可选，保留兼容）**

保留 `llmEnabledProvider` 但弃用，改为 `llmModeProvider`。
旧的 `llmEnabledProvider` 可以保留但内部委托给新的 `llmModeProvider`。

- [ ] **Step 4: 验证**

Run: `lsp_diagnostics filePath="lib/features/gallery/gallery_provider.dart"`

- [ ] **Step 5: Commit**

```bash
git add lib/features/gallery/gallery_provider.dart
git commit -m "feat: 添加 LlmMode、LocalLlmConfig、VisionEnricher 等 Provider"
```

#### Task 4.2: 更新分析调度器配置写法

**Files:**
- Modify: `lib/features/gallery/gallery_provider.dart`
- Modify: `lib/services/analysis_queue_scheduler.dart`

- [ ] **Step 1: 将旧的 llmEnabled setter 改为从 mode 推断**

在 `analysisSchedulerProvider` 中，用 `llmModeProvider` 替代 `llmEnabledProvider`：

```dart
// 移除:
scheduler.setLlmEnabled(ref.read(llmEnabledProvider));
// 改为:
final mode = ref.read(llmModeProvider);
scheduler.setLlmEnabled(mode != LlmMode.off);
```

同时让 scheduler 监听的 llmMode 变化，重启分析时自动应用。

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/features/gallery/gallery_provider.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/features/gallery/gallery_provider.dart lib/services/analysis_queue_scheduler.dart
git commit -m "refactor: 使用 LlmMode 替代旧的 llmEnabled boolean"
```

---

### Chunk 5: 设置 UI

#### Task 5.1: 创建 LLM 设置页面

**Files:**
- Create: `lib/features/settings/llm_settings_screen.dart`

- [ ] **Step 1: 创建 LLM 设置页面**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/llm/config.dart';
import '../../core/llm/local_config.dart';
import '../../features/gallery/gallery_provider.dart';

class LlmSettingsScreen extends ConsumerWidget {
  const LlmSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(llmModeProvider);
    final llmConfig = ref.watch(llmConfigProvider);
    final localConfig = ref.watch(localLlmConfigProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI 标签与描述')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 模式选择
          Text('分析模式', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<LlmMode>(
            segments: const [
              ButtonSegment(value: LlmMode.off, label: Text('关闭')),
              ButtonSegment(value: LlmMode.remote, label: Text('远程 API')),
              ButtonSegment(value: LlmMode.local, label: Text('本地模型')),
            ],
            selected: {mode},
            onSelectionChanged: (selected) {
              ref.read(llmModeProvider.notifier).setMode(selected.first);
            },
          ),
          const SizedBox(height: 24),

          // 远程模式配置
          if (mode == LlmMode.remote) ...[
            Text('远程 API 配置',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: llmConfig.baseUrl,
              decoration: const InputDecoration(
                labelText: 'Endpoint',
                hintText: 'http://localhost:11434',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                llmConfig.copyWith(baseUrl: v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: llmConfig.apiKey,
              decoration: const InputDecoration(
                labelText: 'API Key',
                hintText: 'sk-...',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                llmConfig.copyWith(apiKey: v),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: llmConfig.model,
              decoration: const InputDecoration(
                labelText: '模型',
                hintText: 'gpt-4o-mini',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => ref.read(llmConfigProvider.notifier).update(
                llmConfig.copyWith(model: v),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<LlmProviderType>(
              value: llmConfig.provider,
              decoration: const InputDecoration(
                labelText: '供应商',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: LlmProviderType.openai,
                  child: Text('OpenAI'),
                ),
                DropdownMenuItem(
                  value: LlmProviderType.ollama,
                  child: Text('Ollama'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  ref.read(llmConfigProvider.notifier).update(
                    llmConfig.copyWith(provider: v),
                  );
                }
              },
            ),
          ],

          // 本地模式配置
          if (mode == LlmMode.local) ...[
            Text('本地模型',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            // 模型列表（占位）
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('暂无已下载的模型'),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: 打开模型下载页面
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('模型管理即将实现')),
                        );
                      },
                      icon: const Icon(Icons.download),
                      label: const Text('管理模型'),
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
}
```

- [ ] **Step 2: 验证**

Run: `lsp_diagnostics filePath="lib/features/settings/llm_settings_screen.dart"`

- [ ] **Step 3: Commit**

```bash
git add lib/features/settings/llm_settings_screen.dart
git commit -m "feat: 创建 LLM 设置页面（模式选择 + 远程/本地配置）"
```

#### Task 5.2: 更新主设置页面，链接到 LLM 设置

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`
- Modify: `lib/router.dart`

- [ ] **Step 1: 在设置页面添加 LLM 设置入口**

在 settings_screen.dart 的 LLM 区域，添加跳转到 llm-settings 的 ListTile：

```dart
ListTile(
  leading: const Icon(Icons.auto_awesome),
  title: const Text('AI 标签与描述'),
  subtitle: Text(
    ref.watch(llmModeProvider) == LlmMode.off
        ? '已关闭'
        : ref.watch(llmModeProvider) == LlmMode.remote
            ? '远程 (${ref.watch(llmConfigProvider).model})'
            : '本地模式',
  ),
  onTap: () => context.push('/settings/llm'),
),
```

- [ ] **Step 2: 添加路由**

```dart
// 在 router.dart 的 routes 中添加：
GoRoute(
  path: 'settings/llm',
  name: 'llm-settings',
  builder: (context, state) => const LlmSettingsScreen(),
),
```

- [ ] **Step 3: 验证**

Run: `lsp_diagnostics filePath="lib/features/settings/settings_screen.dart"`
Run: `lsp_diagnostics filePath="lib/router.dart"`

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/settings_screen.dart lib/router.dart
git commit -m "feat: 设置页面添加 LLM 设置入口和路由"
```

---

### Chunk 6: 辅助功能

#### Task 6.1: 添加 LogService 集成（VisionLLM tag 日志）

**Files:**
- Already covered in Task 3.1 - VisionLlmEnricher 已经使用 `_log` 记录所有操作

确认所有 `_log.info/warning/error` 调用使用 `'VisionLLM'` tag。

- [ ] **Step 1: 检查 VisionLlmEnricher 中的日志覆盖**

确保这些场景都有日志：
- 开始分析 ✓
- 图片 base64 大小 ✓
- LLM 返回空结果 ✓
- 保存标签 ✓
- 保存描述 ✓
- 解析失败 ✓
- 异常 ✓
- LLM 不可用 ✓

- [ ] **Step 2: Commit（如果修改了日志）**

```bash
git add lib/core/llm/vision_enricher.dart
git commit -m "chore: VisionLlmEnricher 完善日志记录"
```

#### Task 6.2: llamafu 依赖 + 本地推理实现（安卓优先）

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/core/llm/local_service.dart`

- [ ] **Step 1: 在 pubspec.yaml 中添加 llamafu 依赖**

```yaml
dependencies:
  llamafu: ^0.1.0
```

- [ ] **Step 2: 运行 flutter pub get**

```bash
flutter pub get
```

- [ ] **Step 3: 实现 LocalLlmService 的真实推理（基于 llamafu API）**

**Note:** llamafu API 需要在集成时确认实际接口。假设接口为：

```dart
import 'package:llamafu/llamafu.dart';

class LocalLlmService implements LlmService {
  Llamafu? _engine;
  final LocalLlmConfig _config;

  LocalLlmService({required LocalLlmConfig config}) : _config = config;

  @override
  bool get isAvailable => _config.modelPath != null;

  @override
  String get modelName {
    final path = _config.modelPath;
    if (path == null) return 'none';
    return path.split('/').last.replaceAll('.gguf', '');
  }

  Future<void> _ensureLoaded() async {
    if (_engine != null) return;
    if (_config.modelPath == null) {
      throw StateError('模型未加载，请先下载模型');
    }

    _engine = await Llamafu.init(
      modelPath: _config.modelPath!,
      mmprojPath: _config.mmprojPath,
      nCtx: _config.contextSize,
      nThreads: _config.threads,
      useGpu: _config.useGpu,
    );
  }

  @override
  Future<String> chat(
    List<LlmMessage> messages, {
    LlmOptions? options,
  }) async {
    await _ensureLoaded();

    final hasImage = messages.any((m) => m.imageBase64 != null);
    final prompt = messages.map((m) => '${m.role}: ${m.content}').join('\n');

    if (hasImage && _engine!.supportsMultimodal) {
      // 多模态
      final imageMsg = messages.firstWhere((m) => m.imageBase64 != null);
      final result = await _engine!.multimodalComplete(
        prompt: prompt,
        imageBase64: imageMsg.imageBase64!,
        temperature: options?.temperature ?? 0.7,
        maxTokens: options?.maxTokens ?? 512,
      );
      return result.text;
    } else {
      // 纯文本
      final result = await _engine!.complete(
        prompt: prompt,
        temperature: options?.temperature ?? 0.7,
        maxTokens: options?.maxTokens ?? 512,
      );
      return result.text;
    }
  }

  @override
  void dispose() {
    _engine?.close();
    _engine = null;
  }
}
```

- [ ] **Step 4: 验证编译**

```bash
flutter analyze lib/core/llm/local_service.dart
```

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/core/llm/local_service.dart
git commit -m "feat: 集成 llamafu，实现 LocalLlmService 本地推理"
```

---

### 验证清单

完成后验证：

- [ ] `flutter analyze` 无新增错误
- [ ] 远程模式下，分析管线能调用 OpenAI vision API 生成标签
- [ ] 关闭模式下，管线跳过 LLM 步骤
- [ ] 设置页面模式切换即时生效
- [ ] LlmConfig/LocalLlmConfig 重启后持久化
- [ ] 日志文件中有 VisionLLM 记录的完整分析日志
