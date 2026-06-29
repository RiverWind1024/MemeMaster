# MemeHelper 技术架构文档

> 所属项目: MemeHelper — Meme 表情包管理工具
> 文档编号: 01-architecture.md
> 基于设计: 2026-06-29-meme-manager-design.md

---

## 1. 分层架构总览

App 采用严格分层架构，**上层依赖下层，禁止跨层调用**。

```
┌──────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                        │
│                                                                  │
│  Screens:                                                        │
│   GalleryScreen  SearchScreen  FolderScreen  MemeDetailScreen   │
│   SettingsScreen  ImportScreen  SyncConfigScreen  ModelManager  │
│                                                                  │
│  Widgets:                                                        │
│   MemeGridTile  ColorChipRow  ColorPicker  AnalysisBadge        │
│   ImportProgressCard  SearchBar  FilterChips  TagEditor         │
│                                                                  │
│  DIALOGS / BOTTOM SHEETS:                                        │
│   ImportSourceSheet  ColorPickerSheet  FolderPickerSheet         │
└────────────────────────────────────────────────┬─────────────────┘
                                                 │  reads notifiers
┌────────────────────────────────────────────────┴─────────────────┐
│                       STATE LAYER (Riverpod)                     │
│                                                                  │
│  ┌────────────────────┐  ┌────────────────────┐                 │
│  │  State Notifiers   │  │  Async Providers   │                 │
│  │                    │  │                    │                 │
│  │  memeListProvider  │  │  memeDetailProvider │                 │
│  │  searchProvider    │  │  folderTreeProvider │                 │
│  │  importProvider    │  │  syncStatusProvider │                 │
│  │  analysisProvider  │  │  modelListProvider  │                 │
│  │  settingsProvider  │  │  colorSearchProvider│                 │
│  └────────┬───────────┘  └────────┬───────────┘                 │
└───────────┼───────────────────────┼─────────────────────────────┘
            │  calls services       │
┌───────────┴───────────────────────┴─────────────────────────────┐
│                         SERVICE LAYER                           │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │  ImportService  │  │  AnalysisService │  │  SearchService  │  │
│  │                 │  │                 │  │                 │  │
│  │ • batchImport() │  │ • analyzeOne()  │  │ • semantic()    │  │
│  │ • importZip()   │  │ • processQueue()│  │ • byColor()     │  │
│  │ • importDir()   │  │ • retryFailed() │  │ • hybrid()      │  │
│  │ • dedupCheck()  │  │ • cancelJob()   │  │ • suggest()     │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
│                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │
│  │   SyncService   │  │   ExportService  │  │  ModelService   │  │
│  │                 │  │                 │  │                 │  │
│  │ • push()        │  │ • exportAll()   │  │ • download()    │  │
│  │ • pull()        │  │ • exportOne()   │  │ • delete()      │  │
│  │ • resolve()     │  │ • share()       │  │ • listLocal()   │  │
│  │ • validate()    │  │                 │  │ • load()        │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘  │
└───────────┬──────────────────────────────────────────────────────┘
            │  calls repositories
┌───────────┴──────────────────────────────────────────────────────┐
│                       REPOSITORY LAYER                           │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ MemeRepo     │  │ FolderRepo   │  │ TagRepo              │   │
│  │ • insert()   │  │ • insert()   │  │ • insertBatch()      │   │
│  │ • getById()  │  │ • getTree()  │  │ • getByMemeId()     │   │
│  │ • update()   │  │ • move()     │  │ • deleteByMemeId()  │   │
│  │ • delete()   │  │ • delete()   │  │ • searchByContent() │   │
│  │ • search()   │  └──────────────┘  └──────────────────────┘   │
│  │ • findByHash()│                                            │
│  └──────────────┘                                            │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐   │
│  │ ColorRepo    │  │ EmbedRepo    │  │ SyncStateRepo        │   │
│  │ • insertBatch│  │ • upsert()   │  │ • getLastSyncTime()  │   │
│  │ • getByMeme  │  │ • searchSim()│  │ • setLastSyncTime()  │   │
│  │ • searchByΔE │  │ • delete()   │  │ • getManifest()      │   │
│  └──────────────┘  └──────────────┘  └──────────────────────┘   │
└───────────┬──────────────────────────────────────────────────────┘
            │  reads/writes data sources
┌───────────┴──────────────────────────────────────────────────────┐
│                         DATA LAYER                               │
│                                                                  │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │    Drift Database    │  │    File System       │             │
│  │                      │  │                      │             │
│  │  • meme_helper.db    │  │  • memes/ (images)   │             │
│  │  • 8 tables          │  │  • models/ (GGUF)    │             │
│  │  • sqlite-vec ext    │  │  • temp/ (zips)      │             │
│  │  • migration v1..vN  │  │  • exports/ (sync)   │             │
│  └──────────────────────┘  └──────────────────────┘             │
│                                                                  │
│  ┌──────────────────────┐  ┌──────────────────────┐             │
│  │   llama.cpp .so      │  │   ML Kit (platform)  │             │
│  │                      │  │                      │             │
│  │  • dart:ffi bridge   │  │  • TextRecognizer    │             │
│  │  • GGUF model loader │  │  • platform channel  │             │
│  │  • inference API     │  │  • DigitalInk (opt)  │             │
│  │  • embedding API     │  │                      │             │
│  └──────────────────────┘  └──────────────────────┘             │
└──────────────────────────────────────────────────────────────────┘
```

### 1.1 分层规则

| 层 | 允许依赖 | 禁止依赖 |
|----|---------|---------|
| Presentation | State Layer 的 Provider | 直接调用 Service / Repository / Data |
| State (Riverpod) | Service Layer | 直接操作 Data Layer |
| Service | Repository Layer | 直接操作 UI / State |
| Repository | Data Layer (Database / FileSystem) | 直接操作 UI / Service |
| Data | 无下层 | 被所有上层依赖 |

---

## 2. 模块依赖关系

### 2.1 依赖图（有向）

```
features/gallery  ──→  core/database (via providers)
features/search  ───→  core/database, core/embedding
features/import  ───→  core/database, core/image
features/folders ───→  core/database
features/sync    ───→  core/database
features/settings───→  core/llm, core/database

core/ocr         ───→  platform_channel (ML Kit)
core/llm         ───→  llama.cpp (.so via dart:ffi)
core/embedding   ───→  core/llm (for embedding inference)
core/image       ───→  dart:image library
core/database    ───→  drift, sqlite-vec (no internal project deps)
```

### 2.2 严格依赖规则

1. **Features 不能互相依赖**：gallery 和 search 通过共享的 provider 通信，不直接引用
2. **Core 模块不能依赖 Features**：core/database 不了解任何 UI 概念
3. **Core 模块之间平级调用**：core/embedding 可以调 core/llm（llm 是基础设施）
4. **循环依赖禁止**：若出现 A→B→A 的情况，拆出公共子模块

---

## 3. 依赖注入设计（Riverpod）

### 3.1 Provider 层次

```
// ── Data Layer Providers ──
@riverpod
AppDatabase database(AppDatabaseRef) => AppDatabase();

@riverpod
FileSystem fileSystem(FileSystemRef) => LocalFileSystem();

// ── Repository Providers ──
@riverpod
MemeRepository memeRepository(MemeRepositoryRef) =>
    MemeRepository(database: ref.watch(databaseProvider));

@riverpod
FolderRepository folderRepository(FolderRepositoryRef) =>
    FolderRepository(database: ref.watch(databaseProvider));

@riverpod
ColorRepository colorRepository(ColorRepositoryRef) =>
    ColorRepository(database: ref.watch(databaseProvider));

@riverpod
EmbeddingRepository embeddingRepository(EmbeddingRepositoryRef) =>
    EmbeddingRepository(database: ref.watch(databaseProvider));

// ── Service Providers ──
@riverpod
ImportService importService(ImportServiceRef) => ImportService(
    memeRepo: ref.watch(memeRepositoryProvider),
    folderRepo: ref.watch(folderRepositoryProvider),
    fileSystem: ref.watch(fileSystemProvider),
);

@riverpod
AnalysisService analysisService(AnalysisServiceRef) => AnalysisService(
    memeRepo: ref.watch(memeRepositoryProvider),
    tagRepo: ref.watch(tagRepositoryProvider),
    colorRepo: ref.watch(colorRepositoryProvider),
    embedRepo: ref.watch(embeddingRepositoryProvider),
    llmService: ref.watch(llmServiceProvider),
    ocrService: ref.watch(ocrServiceProvider),
    colorExtractor: ref.watch(colorExtractorProvider),
);

@riverpod
SearchService searchService(SearchServiceRef) => SearchService(
    memeRepo: ref.watch(memeRepositoryProvider),
    tagRepo: ref.watch(tagRepositoryProvider),
    colorRepo: ref.watch(colorRepositoryProvider),
    embedRepo: ref.watch(embeddingRepositoryProvider),
    llmService: ref.watch(llmServiceProvider),
);

// ── State Notifier Providers ──
@riverpod
class MemeList extends _$MemeList {
  // fetch, paginate, filter
}

@riverpod
class SearchState extends _$SearchState {
  // query, color filters, results
}
```

### 3.2 生命周期管理

| 服务 | 生命周期 | 理由 |
|------|---------|------|
| AppDatabase | Singleton (keepAlive) | SQLite 全局唯一实例 |
| FileSystem | Singleton | 文件系统操作无状态 |
| Repositories | Singleton | 无状态，依赖仅 database |
| LLMService | Singleton | llama.cpp native 实例全局唯一 |
| AnalysisService | Singleton | 管理后台队列，有内部状态 |
| SearchService | Singleton | 无状态，纯计算 |
| State Notifiers | autoDispose | 离开页面即释放 |

---

## 4. 错误处理策略

### 4.1 异常类型层级

```
Exception
├── AppException (所有 App 异常的基类)
│   ├── DataException
│   │   ├── DatabaseException (SQL 错误、约束违反)
│   │   ├── FileSystemException (读写失败、空间不足)
│   │   └── NotFoundException (记录不存在)
│   ├── ServiceException
│   │   ├── ImportException (导入过程出错)
│   │   │   ├── ZipCorruptException
│   │   │   ├── DuplicateException
│   │   │   └── UnsupportedFormatException
│   │   ├── AnalysisException (分析管线出错)
│   │   │   ├── OcrException
│   │   │   ├── LlmInferenceException
│   │   │   └── ColorExtractionException
│   │   ├── SearchException (搜索异常)
│   │   └── SyncException (同步异常)
│   │       ├── NetworkException
│   │       ├── AuthException (S3 凭证失效)
│   │       └── ConflictException
│   └── ConfigException (配置错误)
└── ExternalException (来自原生层)
```

### 4.2 错误传播路径

```
Repository Layer:
  try {
    return await dao.insertMeme(meme);
  } on SqliteException catch (e) {
    throw DatabaseException('写入 meme 失败: ${e.message}');
  }

Service Layer:
  try {
    await memeRepo.insert(meme);
    await analysisQueueRepo.enqueue(meme.id);
  } on DuplicateException {
    // 静默跳过，不影响其他导入
    return ImportResult.skipped(reason: 'duplicate');
  } on FileSystemException catch (e) {
    throw ImportException('文件复制失败: ${e.message}');
  }

State Layer:
  AsyncValue<List<Meme>>.error(
    AppError(
      message: '导入失败',
      detail: e.userFriendlyMessage,
      retry: () => ref.read(importProvider.notifier).retry(),
    ),
  );

UI Layer:
  error.when(
    error: (err, stack) => ErrorCard(
      message: err.message,
      onRetry: err.retry,
    ),
  );
```

### 4.3 用户可见的错误信息

| 原始异常 | 用户提示 |
|---------|---------|
| `DatabaseException` | "数据库异常，请重启 App" |
| `FileSystemException` | "存储空间不足或文件访问失败" |
| `ZipCorruptException` | "压缩包已损坏，无法解压" |
| `DuplicateException` | "已跳过 N 个重复的表情包" |
| `OcrException` | "文字识别失败，已跳过此步骤" |
| `LlmInferenceException` | "AI 分析失败，可稍后重试" |
| `NetworkException` | "网络连接失败，请检查网络" |
| `AuthException` | "S3 凭证无效，请在设置中重新配置" |

### 4.4 重试策略

| 场景 | 重试方式 | 最大次数 |
|------|---------|---------|
| LLM 推理失败 | 后台自动重新入队 | 3 次，指数退避 (5s, 30s, 120s) |
| S3 网络超时 | 自动重试 | 3 次 (1s, 5s, 15s) |
| OCR 失败 | 不重试（ML Kit 端侧失败通常是图片问题） | 0 次，标记为 done（跳过 OCR） |
| 数据库写入失败 | 不重试（通常是约束违反，重试无意义） | 0 次 |
| 模型下载中断 | 支持断点续传（Range header） | 不限 |

---

## 5. 异步处理架构

### 5.1 Isolate 管理

```
主 Isolate (UI Thread)
    │
    ├── Riverpod Providers (状态管理)
    ├── Widget Tree (渲染)
    └── Platform Channel (ML Kit OCR)
    
后台 Isolate Pool (最多 2 个)
    │
    ├── Isolate #1: 分析任务 A (llama.cpp 推理)
    ├── Isolate #2: 分析任务 B (颜色提取 + OCR 后处理)
    │
    └── 通信协议:
        SendPort → ReceivePort
        ┌────────────────────────────────────────────┐
        │ 消息类型:                                   │
        │ • AnalysisProgress{memeId, step, percent}  │
        │ • AnalysisResult{memeId, tags, colors, vec}│
        │ • AnalysisError{memeId, error, retryable}  │
        └────────────────────────────────────────────┘
```

### 5.2 分析队列调度

```
AnalysisQueue (数据库表)
    │
    ▼
pollQueue():
    ① SELECT * FROM analysis_queue
       WHERE status = 'queued'
       ORDER BY priority DESC, created_at ASC
       LIMIT 2
    ② 启动 isolate 处理
    ③ 完成后更新 status = 'done' 或 'failed'
    ④ 发出进度通知到主 Isolate
    ⑤ 继续 poll (间隔 3 秒)

资源保护:
    - 同时活跃 isolate ≤ 2
    - llama.cpp 推理串行化（内部请求队列）
    - 每个 isolate 内存预算: ~100MB
    - 总后台内存预算: ~300MB（含模型）
```

---

## 6. 配置与环境

### 6.1 配置模型

```dart
@freezed
class AppConfig with _$AppConfig {
  const factory AppConfig({
    /// S3 配置
    String? s3Endpoint,
    String? s3Bucket,
    String? s3Region,
    String? s3AccessKey,    // 敏感，不序列化到明文
    String? s3SecretKey,    // 敏感，不序列化到明文

    /// 模型配置
    String? multimodalModelPath,   // 多模态 LLM 的 GGUF 路径
    String? embeddingModelPath,    // Embedding 模型的 GGUF 路径

    /// 搜索权重
    @Default(0.6) double semanticWeight,
    @Default(0.3) double colorWeight,
    @Default(0.1) double keywordWeight,

    /// 同步配置
    @Default(true) bool syncOnWifiOnly,
    @Default(false) bool syncOnMobileData,
  }) = _AppConfig;

  factory AppConfig.fromJson(Map<String, dynamic> json) =>
      _$AppConfigFromJson(json);
}
```

### 6.2 配置持久化

| 配置类型 | 存储位置 | 说明 |
|---------|---------|------|
| S3 Access/Secret Key | `flutter_secure_storage` | 加密存储（Android EncryptedSharedPreferences） |
| 搜索权重 | SharedPreferences | 非敏感，频繁读取 |
| 模型路径 | SharedPreferences | 存相对路径，启动时拼接 |
| Feature Flags | SharedPreferences | 灰度开关 |

### 6.3 环境分离

```
lib/
  ├── main.dart                      ← 入口，生产环境
  ├── main_dev.dart                  ← 开发入口（热重载专用配置）
  └── core/
      └── env/
          ├── app_env.dart           ← 环境抽象
          ├── dev_env.dart           ← 开发: 模拟数据、debug 菜单
          └── prod_env.dart          ← 生产: 正式 S3、分析队列
```

---

## 7. 文件组织结构

```
lib/
├── main.dart                          # App 入口
│
├── app.dart                           # MaterialApp + 路由
├── router.dart                        # go_router 定义
│
├── core/
│   ├── database/
│   │   ├── app_database.dart          # drift Database 定义
│   │   ├── app_database.g.dart        # (自动生成)
│   │   ├── tables/
│   │   │   ├── memes_table.dart       # memes 表定义
│   │   │   ├── folders_table.dart
│   │   │   ├── tags_table.dart
│   │   │   ├── colors_table.dart
│   │   │   ├── embeddings_table.dart
│   │   │   ├── analysis_queue_table.dart
│   │   │   └── sync_state_table.dart
│   │   ├── daos/
│   │   │   ├── meme_dao.dart
│   │   │   ├── folder_dao.dart
│   │   │   ├── tag_dao.dart
│   │   │   ├── color_dao.dart
│   │   │   ├── embedding_dao.dart
│   │   │   └── analysis_queue_dao.dart
│   │   └── migrations/
│   │       ├── migration_1_to_2.dart
│   │       └── migration_2_to_3.dart
│   │
│   ├── llm/
│   │   ├── llm_service.dart           # llama.cpp FFI 封装
│   │   ├── llm_bindings.dart          # dart:ffi 函数声明
│   │   ├── model_manager.dart         # 模型下载/删除/列表
│   │   └── model_downloader.dart      # 断点续传下载器
│   │
│   ├── ocr/
│   │   ├── ocr_service.dart           # ML Kit OCR 封装
│   │   └── ocr_platform_channel.dart  # platform channel 通信
│   │
│   ├── image/
│   │   ├── color_extractor.dart       # 主色调提取
│   │   ├── color_utils.dart           # RGB/LAB 转换、ΔE 计算
│   │   └── thumbnail_generator.dart   # 缩略图生成
│   │
│   ├── embedding/
│   │   └── embedding_service.dart     # 向量生成 + 搜索
│   │
│   ├── env/
│   │   ├── app_env.dart
│   │   └── prod_env.dart
│   │
│   └── errors/
│       ├── app_exception.dart          # 异常基类
│       ├── data_exception.dart
│       ├── service_exception.dart
│       └── error_handler.dart         # 统一错误处理
│
├── features/
│   ├── gallery/
│   │   ├── providers/
│   │   │   └── meme_list_provider.dart
│   │   ├── screens/
│   │   │   └── gallery_screen.dart
│   │   └── widgets/
│   │       ├── meme_grid_tile.dart
│   │       └── meme_list_view.dart
│   │
│   ├── search/
│   │   ├── providers/
│   │   │   └── search_provider.dart
│   │   ├── screens/
│   │   │   └── search_screen.dart
│   │   └── widgets/
│   │       ├── search_bar.dart
│   │       ├── color_chip_row.dart
│   │       └── color_picker_sheet.dart
│   │
│   ├── detail/
│   │   ├── providers/
│   │   │   └── meme_detail_provider.dart
│   │   ├── screens/
│   │   │   └── meme_detail_screen.dart
│   │   └── widgets/
│   │       ├── tag_editor.dart
│   │       └── color_swatch.dart
│   │
│   ├── import/
│   │   ├── providers/
│   │   │   └── import_provider.dart
│   │   ├── screens/
│   │   │   └── import_screen.dart
│   │   └── widgets/
│   │       ├── import_source_sheet.dart
│   │       └── import_progress_card.dart
│   │
│   ├── folders/
│   │   ├── providers/
│   │   │   └── folder_provider.dart
│   │   ├── screens/
│   │   │   └── folder_screen.dart
│   │   └── widgets/
│   │       └── folder_tree.dart
│   │
│   ├── sync/
│   │   ├── providers/
│   │   │   └── sync_provider.dart
│   │   ├── screens/
│   │   │   └── sync_config_screen.dart
│   │   └── widgets/
│   │       └── sync_status_card.dart
│   │
│   └── settings/
│       ├── providers/
│       │   └── settings_provider.dart
│       ├── screens/
│       │   └── settings_screen.dart
│       └── widgets/
│           ├── model_manager.dart
│           └── search_weight_sliders.dart
│
└── shared/
    ├── widgets/
    │   ├── empty_state.dart
    │   ├── error_card.dart
    │   ├── loading_skeleton.dart
    │   └── confirm_dialog.dart
    └── utils/
        ├── file_utils.dart
        ├── date_utils.dart
        └── debouncer.dart
```

### 7.1 命名规范

| 元素 | 规范 | 示例 |
|------|------|------|
| 文件名 | snake_case | `meme_list_provider.dart` |
| 类名 | PascalCase | `MemeRepository`, `ImportService` |
| 方法 | camelCase | `batchImport()`, `searchByColor()` |
| Provider | camelCase | `memeListProvider` |
| Riverpod 生成 | `_$类名` | `_$MemeList` |
| 表定义类 | PascalCase + Table | `MemesTable`, `TagsTable` |
| DAO 方法 | 动词开头 | `insertMeme`, `findByHash`, `searchSimilar` |

---

## 8. 关键设计决策记录 (ADR)

### ADR-1: 为什么用 drift 而不是 raw SQLite

- **drift** 提供类型安全、自动 migration、DAO 模式、流式查询
- SQLite raw API 容易写错 SQL 类型，migration 需要手动管理
- 社区活跃，Flutter 生态首选 ORM

### ADR-2: 为什么用 Riverpod 而不是 BLoC

- Riverpod 编译安全（无 runtime ProviderNotFoundException）
- 天然支持异步（AsyncValue），适合大量异步操作（分析、搜索、同步）
- 代码量比 BLoC 少约 40%，适合单人/小团队项目

### ADR-3: 为什么 Features 之间不直接引用

- 防止循环依赖
- 确保每个 Feature 可以独立测试
- 共享逻辑通过 core 层 + 全局 provider 实现

### ADR-4: 为什么搜索权重默认语义 > 颜色 > 关键词

- 用户大部分搜索场景是语义化的（"找一张悲伤的猫"）
- 颜色搜索是辅助手段（"大概是蓝色的"）
- 关键词是兜底方案（向量搜索未覆盖的场景）
- 用户可自行在设置中调整权重
