# MemeHelper 实现计划（一期 · Android）

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现一个可运行的 Android Meme 管理 App，支持图片导入、颜色提取、颜色搜索、OCR 识别、LLM 语义描述、向量搜索和 S3 同步。

**架构:** 严格分层 (Presentation → State/Riverpod → Service → Repository → Data)，Feature-first 组织方式，离线优先。

**Tech Stack:** Flutter 3.x (Material 3), Riverpod 2.x, drift (SQLite ORM), sqlite-vec, dart `image` 库, Google ML Kit, llama.cpp FFI, MinIO S3 SDK, workmanager, flutter_isolate

**设计文档:** `docs/superpowers/specs/2026-06-29-meme-manager-design.md`

---

## 文件结构总览

### 创建的文件结构

```
meme_helper/
├── lib/
│   ├── main.dart
│   ├── app.dart                                  # MaterialApp + 路由 + ProviderScope
│   ├── router.dart                               # go_router 路由定义
│   │
│   ├── core/
│   │   ├── config/
│   │   │   ├── app_config.dart                   # App 常量、默认值
│   │   │   └── pipeline_config.dart              # OCR/LLM toggle 配置
│   │   ├── database/
│   │   │   ├── app_database.dart                 # Drift 数据库定义
│   │   │   ├── app_database.g.dart               # 代码生成
│   │   │   ├── tables/
│   │   │   │   ├── memes_table.dart              # memes 表
│   │   │   │   ├── folders_table.dart            # folders 表
│   │   │   │   ├── tags_table.dart               # tags 表
│   │   │   │   ├── colors_table.dart             # colors 表
│   │   │   │   ├── embeddings_table.dart         # embeddings 表
│   │   │   │   ├── analysis_queue_table.dart     # analysis_queue 表
│   │   │   │   └── sync_state_table.dart         # sync_state 表
│   │   │   ├── daos/
│   │   │   │   ├── meme_dao.dart
│   │   │   │   ├── folder_dao.dart
│   │   │   │   ├── tag_dao.dart
│   │   │   │   ├── color_dao.dart
│   │   │   │   ├── embedding_dao.dart
│   │   │   │   ├── analysis_queue_dao.dart
│   │   │   │   └── sync_state_dao.dart
│   │   │   └── migrations/
│   │   │       └── migration_1.dart              # 初始 migration
│   │   ├── models/
│   │   │   ├── meme.dart
│   │   │   ├── folder.dart
│   │   │   ├── tag.dart
│   │   │   ├── meme_color.dart
│   │   │   ├── embedding.dart
│   │   │   ├── analysis_job.dart
│   │   │   └── sync_state.dart
│   │   ├── image/
│   │   │   ├── color_extractor.dart              # 主色调提取 (MedianCut + LAB)
│   │   │   └── thumbnail_generator.dart          # 缩略图生成
│   │   ├── llm/
│   │   │   ├── llm_bindings.dart                 # dart:ffi 绑定
│   │   │   ├── llm_service.dart                  # llama.cpp 推理封装
│   │   │   ├── embedding_service.dart            # 向量编码服务
│   │   │   └── model_manager.dart                # GGUF 模型下载/管理
│   │   ├── ocr/
│   │   │   └── ocr_service.dart                  # ML Kit OCR 封装
│   │   ├── platform/
│   │   │   └── platform_channels.dart            # MethodChannel 定义
│   │   └── utils/
│   │       ├── color_utils.dart                  # RGB↔LAB 转换, ΔE 计算
│   │       ├── file_utils.dart                   # 文件哈希、路径处理
│   │       └── hash_utils.dart                   # SHA256
│   │
│   ├── data/
│   │   ├── repositories/
│   │   │   ├── meme_repository.dart
│   │   │   ├── folder_repository.dart
│   │   │   ├── tag_repository.dart
│   │   │   ├── color_repository.dart
│   │   │   └── embedding_repository.dart
│   │   └── sync/
│   │       ├── sync_service.dart                 # S3 同步服务
│   │       └── sync_state_repository.dart
│   │
│   ├── services/
│   │   ├── analysis_service.dart                 # 分析管线 (颜色/OCR/LLM)
│   │   ├── analysis_queue_scheduler.dart         # 后台队列调度器
│   │   ├── search_service.dart                   # 混合搜索 (自动降级)
│   │   ├── import_service.dart                   # 导入服务
│   │   └── file_storage_service.dart             # 文件系统操作
│   │
│   └── features/
│       ├── gallery/
│       │   ├── gallery_screen.dart
│       │   ├── gallery_provider.dart             # Riverpod provider
│       │   ├── gallery_grid_tile.dart
│       │   └── meme_detail_screen.dart
│       ├── search/
│       │   ├── search_screen.dart
│       │   ├── search_provider.dart
│       │   └── color_picker_widget.dart
│       ├── import/
│       │   ├── import_screen.dart
│       │   └── import_provider.dart
│       ├── folders/
│       │   ├── folder_screen.dart
│       │   └── folder_provider.dart
│       ├── settings/
│       │   ├── settings_screen.dart
│       │   ├── pipeline_config_screen.dart
│       │   └── model_manager_screen.dart
│       └── sync/
│           ├── sync_config_screen.dart
│           └── sync_provider.dart
│
├── test/
│   ├── core/
│   │   ├── image/
│   │   │   └── color_extractor_test.dart
│   │   └── utils/
│   │       └── color_utils_test.dart
│   ├── data/
│   │   └── repositories/
│   │       ├── meme_repository_test.dart
│   │       └── tag_repository_test.dart
│   ├── services/
│   │   ├── analysis_service_test.dart
│   │   ├── search_service_test.dart
│   │   └── import_service_test.dart
│   └── features/
│       ├── gallery/
│       │   └── gallery_provider_test.dart
│       └── search/
│           └── search_provider_test.dart
│
├── android/
│   ├── app/src/main/
│   │   ├── jniLibs/
│   │   │   └── arm64-v8a/
│   │   │       ├── libllama.so                   # llama.cpp 编译产物 (Phase 5)
│   │   │       └── libggml.so
│   │   ├── kotlin/.../MemeHelperPlugin.kt        # Platform channel 实现 (Phase 4)
│   │   └── AndroidManifest.xml
│   └── ...
│
├── pubspec.yaml
├── build.gradle
└── analysis_options.yaml
```

---

## Phase 0: 项目脚手架搭建

> **目标:** 创建一个编译通过的 Flutter 项目，所有依赖配置完成，代码生成工具就绪。无业务逻辑。

### Task 0.1: Flutter 项目初始化

**Files:**
- Create: `meme_helper/` (Flutter project root)

- [ ] **Step 1: 创建 Flutter 项目**

Run: `flutter create --org com.memehelper --platforms android --project-name meme_helper meme_helper`
Expected: 项目创建成功，`flutter run` 可显示默认 counter 页面

- [ ] **Step 2: 添加 pubspec.yaml 所有依赖**

**Reference:** `09-build-guide.md` 中完整依赖清单

```yaml
dependencies:
  flutter:
    sdk: flutter
  # 状态管理
  flutter_riverpod: ^2.5.0
  riverpod_annotation: ^2.3.0
  # 路由
  go_router: ^14.0.0
  # 数据库
  drift: ^2.16.0
  sqlite3_flutter_libs: ^0.5.0
  path_provider: ^2.1.0
  # 图片处理
  image: ^4.1.0
  # 文件 hash
  crypto: ^3.0.0
  # 同步
  flutter_secure_storage: ^9.2.0
  http: ^1.2.0
  # 后台
  workmanager: ^0.5.2
  flutter_isolate: ^2.0.0
  # 序列化
  freezed_annotation: ^2.4.0
  json_annotation: ^4.9.0
  uuid: ^4.3.0
  # 系统
  collection: ^1.18.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  drift_dev: ^2.16.0
  riverpod_generator: ^2.4.0
  freezed: ^2.5.0
  json_serializable: ^6.8.0
  build_runner: ^2.4.0
  flutter_lints: ^3.0.0
  mocktail: ^1.0.0
```

Run: `flutter pub get`
Expected: 所有依赖下载成功，无冲突

- [ ] **Step 3: 配置分析选项**

Modify: `analysis_options.yaml`

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_declarations: true
    prefer_final_locals: true
    avoid_print: false
```

- [ ] **Step 4: 配置 Android Gradle**
  - `minSdk` = 26
  - `ndkVersion` 指向已安装的 NDK
  - 启用 `abiFilters "arm64-v8a"`

**Reference:** `09-build-guide.md` Gradle 配置

- [ ] **Step 5: 验证项目编译**

Run: `flutter build apk --debug`
Expected: BUILD SUCCESSFUL，生成 APK

---

## Phase 1: 数据层（数据库 + Models + Repositories）

> **目标:** 所有 drift 表定义完成，DAO 实现并通过单元测试，Repository 包装完成。此阶段可纯单元测试验证。

### Task 1.1: 定义数据模型（freezed）

**Files:**
- Create: `lib/core/models/meme.dart`
- Create: `lib/core/models/folder.dart`
- Create: `lib/core/models/tag.dart`
- Create: `lib/core/models/meme_color.dart`
- Create: `lib/core/models/embedding.dart`
- Create: `lib/core/models/analysis_job.dart`
- Create: `lib/core/models/sync_state.dart`

- [ ] **Step 1: 创建 Meme 模型**

```dart
// lib/core/models/meme.dart
@freezed
class Meme with _$Meme {
  const factory Meme({
    required String id,           // UUID
    required String filename,
    required String filePath,     // 内部存储相对路径
    required int fileSize,
    required String mimeType,
    int? width,
    int? height,
    String? folderId,
    @Default('pending') String analysisStatus,
    required String fileHash,     // SHA256
    required int createdAt,       // unix ms
    required int updatedAt,
    required int importedAt,
  }) = _Meme;

  factory Meme.fromJson(Map<String, dynamic> json) => _$MemeFromJson(json);
}
```

- [ ] **Step 2: 创建 Folder / Tag / MemeColor / Embedding / AnalysisJob / SyncState 模型**

所有模型遵循相同模式：freezed + json_serializable

- [ ] **Step 3: 运行代码生成**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: 所有 `.g.dart` 文件生成成功

- [ ] **Step 4: 编写模型单元测试**

```
test/core/models/meme_test.dart
- Meme.fromJson()  ↔ toJson() 对称
- 默认值检查 (analysisStatus 默认为 'pending')
```

### Task 1.2: Drift 数据库表定义

**Files:**
- Create: `lib/core/database/tables/memes_table.dart`
- Create: `lib/core/database/tables/folders_table.dart`
- Create: `lib/core/database/tables/tags_table.dart`
- Create: `lib/core/database/tables/colors_table.dart`
- Create: `lib/core/database/tables/embeddings_table.dart`
- Create: `lib/core/database/tables/analysis_queue_table.dart`
- Create: `lib/core/database/tables/sync_state_table.dart`
- Create: `lib/core/database/app_database.dart`
- Create: `lib/core/database/migrations/migration_1.dart`

- [ ] **Step 1: 定义 memes 表**

```dart
// lib/core/database/tables/memes_table.dart
@UseRowClass(Meme)
class Memes extends Table {
  TextColumn get id => text()();                      // PK
  TextColumn get filename => text()();
  TextColumn get filePath => text()();
  IntColumn get fileSize => integer()();
  TextColumn get mimeType => text()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  TextColumn get folderId => text().nullable()();
  TextColumn get analysisStatus => text()();          // pending/processing/done/failed
  TextColumn get fileHash => text()();                // SHA256, UNIQUE
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  IntColumn get importedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

- [ ] **Step 2: 定义 folders / tags / colors / embeddings / analysis_queue / sync_state 表**

**Reference:** `02-database.md` 完整表定义

关键设计：
- colors 表需包含 `lChannel` / `aChannel` / `bChannel` (预计算 LAB)
- embeddings 表存储 float32 向量 (BLOB)
- analysis_queue 有 `status` + `priority` + `retryCount`
- file_hash 有 UNIQUE 约束用于去重

- [ ] **Step 3: 创建 AppDatabase**

```dart
// lib/core/database/app_database.dart
@DriftDatabase(tables: [Memes, Folders, Tags, Colors, Embeddings, AnalysisQueue, SyncState])
class AppDatabase extends _$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      // sqlite-vec 初始化
      await customStatement('SELECT vec_version()');
    },
  );
}
```

- [ ] **Step 4: 运行 Drift 代码生成**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `app_database.g.dart` 生成成功

- [ ] **Step 5: 编写数据库集成测试**

```
test/core/database/app_database_test.dart
- 创建数据库（使用 NativeDatabase.memory()）
- 插入一条 meme → 查询验证
- file_hash UNIQUE 约束验证
- 插入关联 tags/colors → 级联查询
```

### Task 1.3: DAO 实现

**Files:**
- Create: `lib/core/database/daos/meme_dao.dart`
- Create: `lib/core/database/daos/folder_dao.dart`
- Create: `lib/core/database/daos/tag_dao.dart`
- Create: `lib/core/database/daos/color_dao.dart`
- Create: `lib/core/database/daos/embedding_dao.dart`
- Create: `lib/core/database/daos/analysis_queue_dao.dart`
- Create: `lib/core/database/daos/sync_state_dao.dart`

- [ ] **Step 1: 实现 MemeDao**

```dart
// lib/core/database/daos/meme_dao.dart
@DriftAccessor(tables: [Memes])
class MemeDao extends DatabaseAccessor<AppDatabase> with _$MemeDaoMixin {
  MemeDao(AppDatabase db) : super(db);

  Future<List<Meme>> findAll({String? orderBy, int? limit, int? offset});
  Future<Meme?> findById(String id);
  Future<Meme?> findByHash(String fileHash);      // 去重检查
  Future<List<Meme>> findByStatus(String status);
  Future<List<Meme>> findByFolderId(String folderId);
  Future<int> insertMeme(Insertable<Meme> meme);
  Future<bool> updateMeme(Insertable<Meme> meme);
  Future<int> deleteMeme(String id);
  Future<int> countByStatus(String status);
}
```

- [ ] **Step 2: 实现其他 DAO**

关键查询（参考 `02-database.md`）：
- `TagDao.searchContent('%keyword%', limit)` — 搜索建议
- `ColorDao.findByMemeId(id)` — 获取 meme 的主色调列表
- `AnalysisQueueDao.pollNextJobs(limit)` — 取 queued 任务，按 priority 排序
- `EmbeddingDao.searchSimilar(vector, limit)` — sqlite-vec 余弦相似度

- [ ] **Step 3: DAO 单元测试**

每个 DAO 至少覆盖：insert → read → update → delete 完整 CRUD 周期

### Task 1.4: Repository 实现

**Files:**
- Create: `lib/data/repositories/meme_repository.dart`
- Create: `lib/data/repositories/folder_repository.dart`
- Create: `lib/data/repositories/tag_repository.dart`
- Create: `lib/data/repositories/color_repository.dart`
- Create: `lib/data/repositories/embedding_repository.dart`

- [ ] **Step 1: 实现 MemeRepository**

Repository 层职责：组合 DAO + 文件系统操作 + 领域逻辑

```dart
// lib/data/repositories/meme_repository.dart
class MemeRepository {
  final MemeDao _dao;
  final FileStorageService _storage;

  Future<Meme> importMeme(File sourceFile, {String? folderId}) async {
    // 1. 计算 SHA256
    // 2. 查重 (findByHash)
    // 3. 复制到内部存储
    // 4. 写入 DB
    // 5. 返回 Meme entity
  }

  Future<void> deleteMeme(String id) async {
    // 1. 删除 DB 记录
    // 2. 删除关联 tags/colors/embeddings
    // 3. 删除文件
  }
}
```

- [ ] **Step 2: 实现其他 Repository**

- [ ] **Step 3: Repository 单元测试（使用 mock DAO）**

---

## Phase 2: 颜色提取管线（MVP 里程碑）

> **目标:** 导入图片 → 颜色提取 → 存储 → 颜色搜索。这是第一个可工作的功能闭环。

### Task 2.1: 颜色提取服务

**Files:**
- Create: `lib/core/utils/color_utils.dart`
- Create: `lib/core/image/color_extractor.dart`

- [ ] **Step 1: 实现颜色工具函数**

```dart
// lib/core/utils/color_utils.dart
ColorRgb fromHex(String hex);
ColorLab rgbToLab(ColorRgb rgb);
double deltaE(ColorLab a, ColorLab b);              // CIE76
int hueBin(ColorLab lab);                           // 色相桶: 0-359
```

**Reference:** `03-llm-pipeline.md` 颜色提取部分

- [ ] **Step 2: 编写 `color_utils_test.dart`**
  - RGB→LAB 已知值验证（如纯红 #FF0000 的 Lab 值）
  - ΔE 对称性: deltaE(a, b) == deltaE(b, a)
  - 同色色差: deltaE(c, c) == 0

- [ ] **Step 3: 实现 ColorExtractor**

```dart
// lib/core/image/color_extractor.dart
class ColorExtractor {
  /// 提取图片的 3-5 个主色调
  /// 使用 MedianCut 量化算法
  Future<List<DominantColor>> extract(String imagePath) async {
    // 1. 使用 dart `image` 库解码图片
    final img = decodeImage(File(imagePath).readAsBytesSync());
    // 2. MedianCut 量化到 5 色
    final quantized = quantize(img, colorCount: 5);
    // 3. 排序 (按像素占比降序)
    // 4. 转换为 RGB + LAB
    // 5. 返回 DominantColor 列表
  }
}

class DominantColor {
  final String hex;
  final double lChannel;
  final double aChannel;
  final double bChannel;
  final double ratio;    // 该颜色占图片面积比例 (0.0-1.0)
}
```

- [ ] **Step 4: 编写 `color_extractor_test.dart`**
  - 使用已知颜色的纯色测试图
  - 验证提取的主色调数量在 3-5 之间
  - 验证占比总和 ≈ 1.0

### Task 2.2: 分析队列调度器

**Files:**
- Create: `lib/services/analysis_queue_scheduler.dart`

- [ ] **Step 1: 实现队列调度器**

```dart
// lib/services/analysis_queue_scheduler.dart
class AnalysisQueueScheduler {
  static const int maxConcurrent = 2;
  static const Duration pollInterval = Duration(seconds: 3);

  final AnalysisQueueDao _queueDao;
  final AnalysisService _analysisService;
  final Set<String> _runningJobs = {};
  bool _isRunning = false;

  Future<void> start();
  void stop();
  Future<void> _processNextBatch();
}
```

- [ ] **Step 2: 编写调度器测试**
  - 入队 → 验证被消费
  - 并发限制 (maxConcurrent)
  - 失败重试计数

### Task 2.3: ImportService + FileStorageService

**Files:**
- Create: `lib/services/file_storage_service.dart`
- Create: `lib/services/import_service.dart`

- [ ] **Step 1: 实现 FileStorageService**

```dart
class FileStorageService {
  final String basePath;  // appDir/memes

  Future<String> storeImage(File source, String hash);
  // 目标: appDir/memes/{yyyy}/{mm}/{hash}.{ext}
  Future<void> deleteImage(String relativePath);
  Future<File> getImage(String relativePath);
  Future<int> storageUsed();
}
```

- [ ] **Step 2: 实现 ImportService**

```dart
class ImportService {
  Future<ImportResult> importImages(List<File> files, {String? folderId}) async {
    int success = 0, skipped = 0;
    for (final file in files) {
      // 1. hash 查重
      // 2. 复制到内部存储
      // 3. 写 memes 表
      // 4. 入 analysis_queue
    }
    return ImportResult(success, skipped);
  }
}
```

- [ ] **Step 3: 编写 import_service_test.dart**
  - 模拟文件导入 → 验证 DB 和文件系统调用
  - 重复文件 → 跳过 (skipped 计数增加)

### Task 2.4: 颜色搜索服务

**Files:**
- Create: `lib/services/search_service.dart` (仅颜色搜索部分)

- [ ] **Step 1: 实现 ColorSearchService**

```dart
class ColorSearchService {
  final ColorDao _colorDao;

  Future<List<SearchResult>> searchByColor(ColorRgb target, {int limit = 50}) async {
    final targetLab = rgbToLab(target);
    final targetHue = hueBin(targetLab);

    // 1. 先筛选相同色相桶的 colors (索引加速)
    final candidates = await _colorDao.findByHueBin(targetHue, limit: limit * 2);

    // 2. 精确计算 ΔE
    final scored = candidates.map((c) {
      final cLab = ColorLab(c.lChannel, c.aChannel, c.bChannel);
      return (memeId: c.memeId, deltaE: deltaE(targetLab, cLab));
    });

    // 3. 按色差升序排序
    // 4. 取 TOP limit
  }
}
```

- [ ] **Step 2: 编写颜色搜索测试**
  - 插入已知颜色 → 搜索 → 验证匹配度排序

---

## Phase 3: 核心 UI（MVP 里程碑）

> **目标:** App 可以从相册导入图片，在 Gallery 中看到它们，点击查看详情，按颜色搜索。完整用户闭环。

### Task 3.1: App 入口 + 路由

**Files:**
- Create: `lib/app.dart`
- Create: `lib/router.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: 创建 main.dart**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appDatabase = AppDatabase(await constructDb());
  runApp(
    ProviderScope(overrides: [
      appDatabaseProvider.overrideWithValue(appDatabase),
    ], child: const MemeHelperApp()),
  );
}
```

- [ ] **Step 2: 实现路由**

```dart
// lib/router.dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    StatefulShellRoute.indexedStack(
      branches: [
        // Tab 0: Gallery
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const GalleryScreen()),
        ]),
        // Tab 1: Search (含颜色搜索)
        StatefulShellBranch(routes: [
          GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
        ]),
        // Tab 2: Folders
        StatefulShellBranch(routes: [
          GoRoute(path: '/folders', builder: (_, __) => const FolderScreen()),
        ]),
        // Tab 3: Settings
        StatefulShellBranch(routes: [
          GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        ]),
      ],
    ),
    GoRoute(path: '/meme/:id', builder: (_, state) => MemeDetailScreen(...)),
    GoRoute(path: '/import', builder: (_, __) => const ImportScreen()),
  ],
);
```

### Task 3.2: Gallery 页面

**Files:**
- Create: `lib/features/gallery/gallery_screen.dart`
- Create: `lib/features/gallery/gallery_provider.dart`
- Create: `lib/features/gallery/gallery_grid_tile.dart`

- [ ] **Step 1: 实现 GalleryProvider (Riverpod)**

```dart
@riverpod
class MemeList extends _$MemeList {
  @override
  Future<List<Meme>> build({String? folderId}) async {
    return ref.read(memeRepositoryProvider).findAll(folderId: folderId);
  }

  Future<void> refresh() async => ref.invalidateSelf();
}
```

- [ ] **Step 2: 实现 GalleryScreen**
  - AppBar: 标题 + 导入按钮 (FAB)
  - 网格视图 (GridView, 交叉轴 3 列)
  - 空状态: "还没有表情包" + 导入按钮
  - 下拉刷新
  - 点击 → MemeDetailScreen

- [ ] **Step 3: 实现 GalleryGridTile**
  - 缩略图 (淡入动画, 150ms)
  - 角标 (analysis_status: 灰=pend, 蓝旋转=processing, 绿=done, 红=failed)

### Task 3.3: Meme 详情页

**Files:**
- Create: `lib/features/gallery/meme_detail_screen.dart`

- [ ] **Step 1: 实现详情页**
  - 全屏图片预览 (InteractiveViewer, 支持双指缩放)
  - 信息栏: 文件名、大小、导入时间、分析状态
  - 颜色芯片行: 显示提取的 3-5 个主色
  - 标签列表: 显示 OCR 文本和 LLM 描述
  - AppBar: 返回 + 删除按钮

### Task 3.4: 导入页面

**Files:**
- Create: `lib/features/import/import_screen.dart`
- Create: `lib/features/import/import_provider.dart`

- [ ] **Step 1: 实现 ImportProvider**
  - 管理导入状态 (idle/importing/done/error)
  - 调用 ImportService.importImages()

- [ ] **Step 2: 实现 ImportScreen**
  - FAB 点击 → 底部弹出 ImportSourceSheet
  - 选项: "从相册选择" / "从 ZIP 导入"
  - 导入进度卡片 (进度条 + 数字)
  - 完成 → SnackBar "成功导入 N 张"

### Task 3.5: 搜索页面（颜色搜索）

**Files:**
- Create: `lib/features/search/search_screen.dart`
- Create: `lib/features/search/search_provider.dart`
- Create: `lib/features/search/color_picker_widget.dart`

- [ ] **Step 1: 实现颜色拾取器**
  - 色相滑块 + 饱和度/明度面板
  - 显示当前选中颜色
  - 显示最近使用颜色

- [ ] **Step 2: 实现 SearchProvider**
  - 管理搜索状态 (query, colors, results)
  - 调用 SearchService.search() (仅颜色搜索，此阶段)

- [ ] **Step 3: 实现 SearchScreen**
  - 搜索栏 (展开动画, 250ms)
  - 颜色拾取器
  - 搜索结果网格
  - 空结果: "没找到相关表情包"

### Task 3.6: 系统集成验证

- [ ] **Step 1: 完整流程测试**
  1. 启动 App → Gallery 空状态
  2. 点击 FAB → 导入 3 张图片
  3. 看到导入进度 → 完成后出现在 Gallery
  4. 点击一张 → 详情页看颜色芯片
  5. 返回 → 搜索页 → 选颜色 → 看到匹配结果

---

## Phase 4: OCR 集成 + 管线开关

> **目标:** 设置页可以开关 OCR/LLM，OCR 在开启后自动分析文字。

### Task 4.1: 平台通道 (Platform Channel)

**Files:**
- Create: `lib/core/platform/platform_channels.dart`
- Create: (Android) `android/app/src/main/kotlin/.../MemeHelperPlugin.kt`

- [ ] **Step 1: 定义 Flutter 端 MethodChannel**

```dart
// lib/core/platform/platform_channels.dart
class OcrChannel {
  static const _channel = MethodChannel('meme_helper/ocr');

  static Future<List<OcrResult>> recognizeText(String imagePath) async {
    final results = await _channel.invokeMethod('recognizeText', {
      'imagePath': imagePath,
    });
    return (results as List).map((r) => OcrResult.fromMap(r)).toList();
  }
}

class FilePickerChannel {
  static const _channel = MethodChannel('meme_helper/file_picker');

  static Future<List<String>> pickImages() async { ... }
}
```

- [ ] **Step 2: 实现 Android 端插件**

**Reference:** `08-platform-channels.md` Kotlin 代码

```kotlin
// MemeHelperPlugin.kt
class MemeHelperPlugin : FlutterPlugin, MethodCallHandler {
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "recognizeText" -> {
        val imagePath = call.argument<String>("imagePath")!!
        // 调用 ML Kit TextRecognition
        val recognizer = TextRecognition.getClient()
        val image = InputImage.fromFilePath(context, imagePath)
        recognizer.process(image)
          .addOnSuccessListener { response ->
            val results = it.textBlocks.map { block ->
              mapOf("text" to block.text, "confidence" to 0.9)
            }
            result.success(results)
          }
      }
    }
  }
}
```

- [ ] **Step 3: 注册插件 (MainActivity.kt)**

- [ ] **Step 4: 测试 OCR 通道**
  - 使用测试图片 → 调用 recognizeText → 验证返回文本

### Task 4.2: OCR 服务封装

**Files:**
- Create: `lib/core/ocr/ocr_service.dart`

- [ ] **Step 1: 实现 OcrService**

```dart
class OcrService {
  Future<bool> get isAvailable async {
    // 检查设备是否支持 ML Kit
    return true; // ML Kit 离线可运行
  }

  Future<List<OcrResult>> recognize(String imagePath) async {
    return OcrChannel.recognizeText(imagePath);
  }
}

class OcrResult {
  final String text;
  final double confidence;
  final Rect boundingBox;
}
```

### Task 4.3: 管线配置 + AnalysisService 整合

**Files:**
- Create: `lib/core/config/pipeline_config.dart`
- Create: `lib/services/analysis_service.dart`
- Modify: `lib/services/analysis_queue_scheduler.dart`

- [ ] **Step 1: 实现 PipelineConfig**

```dart
class PipelineConfig {
  final bool ocrEnabled;
  final bool llmEnabled;
  // 默认: {ocrEnabled: false, llmEnabled: false}
}
```

- [ ] **Step 2: 实现 AnalysisService（带 toggle）**

**Reference:** `03-llm-pipeline.md` 5.2 节代码

```dart
class AnalysisService {
  Future<AnalysisResult> analyzeOne(Meme meme) async {
    // 1. 颜色提取 (始终执行)
    // 2. OCR (if config.ocrEnabled && ocrService.isAvailable)
    // 3. LLM (if config.llmEnabled && llmService.isMultimodalModelLoaded)
    // 4. Embedding (if embeddingService.isModelLoaded && tags not empty)
  }
}
```

- [ ] **Step 3: 更新队列调度器** → 使用 AnalysisService

- [ ] **Step 4: 编写 analysis_service_test.dart**
  - 全部 toggle 关闭 → 仅颜色提取
  - OCR toggle 开启 → OCR 执行
  - LLM toggle 开启但模型未下载 → 跳过

### Task 4.4: PipelineConfig 设置 UI

**Files:**
- Create: `lib/features/settings/settings_screen.dart`
- Create: `lib/features/settings/pipeline_config_screen.dart`
- Modify: `lib/router.dart` (添加 /settings/pipeline 路由)

- [ ] **Step 1: 实现 SettingsScreen**
  - "分析管线" 区块: OCR 开关, LLM 开关
  - 当前搜索级别指示 (auto detected)
  - "模型管理" 入口
  - "S3 同步" 入口 (Phase 6)
  - "存储" 信息

- [ ] **Step 2: 实现 PipelineConfigScreen** (可选, 更详细的配置页面)

### Task 4.5: 验证 OCR 完整流程

- [ ] 设置页开启 OCR
- [ ] 导入一张带文字的图片
- [ ] 分析队列自动执行 → OCR 提取文字
- [ ] 详情页显示 OCR 标签
- [ ] 关闭 OCR → 新导入的图片不再执行 OCR

---

## Phase 5: LLM 集成 + 语义搜索

> **目标:** llama.cpp .so 编译与集成，GGUF 模型管理，语义向量搜索。

### Task 5.1: llama.cpp 交叉编译

**Files:**
- Place: `android/app/src/main/jniLibs/arm64-v8a/libllama.so`
- Place: `android/app/src/main/jniLibs/arm64-v8a/libggml.so`

- [ ] **Step 1: NDK 环境准备**
  - 安装 Android NDK (通过 sdkmanager)
  - 确认 NDK 路径

- [ ] **Step 2: 编译 llama.cpp**

**Reference:** `03-llm-pipeline.md` 1.1 节

```bash
cd llama.cpp
mkdir build-android && cd build-android
cmake -DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake \
      -DANDROID_ABI=arm64-v8a \
      -DANDROID_PLATFORM=android-26 \
      -DLLAMA_BUILD_TESTS=OFF \
      -DLLAMA_BUILD_EXAMPLES=OFF \
      -DLLAMA_METAL=OFF \
      -DLLAMA_CUBLAS=OFF \
      -DLLAMA_VULKAN=ON \
      ..
make -j$(nproc)
# 产物: libllama.so, libggml.so
```

- [ ] **Step 3: 复制 .so 到 Flutter 项目**

```bash
cp libllama.so libggml.so ../meme_helper/android/app/src/main/jniLibs/arm64-v8a/
```

### Task 5.2: Dart FFI 绑定

**Files:**
- Create: `lib/core/llm/llm_bindings.dart`
- Create: `lib/core/llm/llm_service.dart`

- [ ] **Step 1: 实现 LLM FFI 绑定**

**Reference:** `03-llm-pipeline.md` 1.2 节

```dart
class LlamaBindings {
  static DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open('libllama.so')
    : DynamicLibrary.process();

  // llama_model_load, llama_eval, llama_embed 等函数映射
}
```

- [ ] **Step 2: 实现 LlmService (推理封装)**

```dart
class LlmService {
  bool get isMultimodalModelLoaded => _model != null;

  Future<void> loadModel(String ggufPath);
  Future<void> unloadModel();

  /// 多模态推理 (图片 → 描述)
  Future<String> multimodalInference({
    required String imagePath,
    required String prompt,
  });

  /// 文本 Embedding
  Future<Uint8List> encode(String text);
}
```

### Task 5.3: 模型管理

**Files:**
- Create: `lib/core/llm/model_manager.dart`
- Create: `lib/features/settings/model_manager_screen.dart`

- [ ] **Step 1: 实现 ModelManager**
  - 模型下载 (Range header 断点续传)
  - 下载进度追踪
  - 删除 / 切换模型
  - 存储空间统计

- [ ] **Step 2: 实现 ModelManagerScreen**
  - 已安装模型列表
  - 下载新模型 (预设下载 URL)
  - 删除模型

### Task 5.4: EmbeddingService + 语义搜索

**Files:**
- Create: `lib/core/llm/embedding_service.dart`
- Modify: `lib/services/search_service.dart` (添加语义搜索)

- [ ] **Step 1: 实现 EmbeddingService**

```dart
class EmbeddingService {
  bool get isModelLoaded;
  String get currentModelId;

  Future<Uint8List> encode(String text);
  Future<void> loadModel(String ggufPath);
}
```

- [ ] **Step 2: 更新 SearchService（添加语义搜索）**

**Reference:** `04-search-engine.md` 4.1 节

- 自动降级: 有 embedding 模型 → 全功能 (L3); 无 → 基础文本 (L2)
- 权重自适应: L3 (0.6/0.3/0.1), L2 (0.0/0.3/0.7)

- [ ] **Step 3: 编写搜索测试**
  - L3 语义搜索
  - L2 关键词搜索
  - 空查询 → 浏览模式

### Task 5.5: 验证 LLM 完整流程

- [ ] 设置页开启 LLM
- [ ] 下载 LLM 模型 (Moondream GGUF)
- [ ] 导入一张图片
- [ ] 分析管线 → LLM 生成描述
- [ ] 搜索 "悲伤" → 返回匹配结果
- [ ] 关闭 LLM → 新图片不执行 LLM

---

## Phase 6: S3 同步 + 文件夹管理

> **目标:** S3 差量同步，多端双向合并。

### Task 6.1: S3 同步服务

**Files:**
- Create: `lib/data/sync/sync_service.dart`
- Create: `lib/data/sync/sync_state_repository.dart`
- Create: `lib/features/sync/sync_config_screen.dart`
- Create: `lib/features/sync/sync_provider.dart`

- [ ] **Step 1: 实现 SyncStateRepository**
  - 记录每个 meme 的上次同步时间戳
  - 记录同步历史

- [ ] **Step 2: 实现 SyncService**

**Reference:** `05-sync-storage.md`

```dart
class SyncService {
  Future<SyncResult> sync() async {
    // 1. 从 S3 下载 manifest.json (所有远端 meme 清单)
    // 2. 与本地同步状态对比 → 计算差异
    // 3. 上传新增/变更
    // 4. 下载远端新增/变更
    // 5. 合并 (updated_at 较新者胜)
  }
}
```

- [ ] **Step 3: 实现 SyncConfigScreen**
  - Endpoint / Bucket / Access Key / Secret Key 配置
  - 测试连接
  - 手动同步按钮

- [ ] **Step 4: 编写同步测试**
  - 模拟 S3 响应 → 验证差异计算
  - 冲突解决 (A 更新 vs B 删除)

### Task 6.2: 文件夹管理

**Files:**
- Create: `lib/features/folders/folder_screen.dart`
- Create: `lib/features/folders/folder_provider.dart`

- [ ] **Step 1: 实现文件夹 CRUD**
  - 创建 / 重命名 / 删除
  - 移动 meme 到文件夹
  - 按文件夹筛选

---

## Phase 7: 设置页完善 + 边缘情况

> **目标:** 修复打磨，处理所有边缘情况。

### Task 7.1: 设置页完整实现

**Files:**
- Modify: `lib/features/settings/settings_screen.dart`

- [ ] **Step 1: 完成设置页所有区块**

设置项：
- AI 模型: 已下载模型列表 + 版本 + 模型管理入口
- 分析管线: OCR/LLM toggle + 当前搜索级别
- S3 同步: 状态 + 手动同步
- 搜索权重: 滑块 (语义/颜色/关键词)
- 存储: 已用空间 + 清除缓存
- 关于: 版本 + 开源协议

### Task 7.2: 边缘情况处理

- [ ] **Step 1: 空状态**
  - 无 meme: 图示 + 引导导入
  - 搜索无结果: "试试颜色搜索" 建议
  - 文件夹为空: 引导移入

- [ ] **Step 2: 错误处理**
  - 导入文件损坏 → SnackBar 提示但不阻塞
  - 存储空间不足 → Dialog 提示清理
  - 分析失败 → 缩略图红点角标, 可点击重试
  - 模型加载失败 → SnackBar 提示

- [ ] **Step 3: 后台恢复**
  - App 被系统杀掉 → 下次启动时恢复未完成的分析任务
  - workmanager 周期性检查队列

- [ ] **Step 4: 性能验证**

**Reference:** `10-performance-budget.md`

- 启动时间 < 2s
- 颜色提取 < 100ms
- 搜索 < 200ms
- 滚动流畅 (55fps+)

---

## 里程碑摘要

| 阶段 | 里程碑 | 交付物 |
|------|--------|--------|
| Phase 0 | 项目就绪 | 编译通过的 Flutter 项目 |
| Phase 1 | 数据层就绪 | 全部单元测试通过的数据库 + Repository |
| **Phase 2** | **颜色 MVP** | **可运行的导入→颜色提取→颜色搜索闭环** |
| **Phase 3** | **核心 UI** | **完整的 Gallery/详情/导入/颜色搜索交互** |
| Phase 4 | OCR 集成 | 可开关的 OCR 文字识别管线 |
| Phase 5 | LLM + 语义搜索 | 可开关的 LLM 描述 + 向量搜索 |
| Phase 6 | 同步 + 文件夹 | S3 增量同步 + 文件夹管理 |
| Phase 7 | 打磨 | 完整的设置页 + 边缘情况处理 |
