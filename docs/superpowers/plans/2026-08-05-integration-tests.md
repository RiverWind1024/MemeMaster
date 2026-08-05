# 服务层集成测试套件实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 MemeHelper 建立服务层集成测试套件，直接调用各功能模块的服务函数（导入/搜索/相册/导出/分析调度），以函数调用成功 + 数据落地正确为通过标准。

**Architecture:** 纯服务层直调，不启动 UI、不经过 Riverpod。`integration_test/test_env.dart` 提供共享测试环境（临时 SQLite 数据库 + 临时存储目录 + 运行时生成测试图片），组装真实服务。为此给 `AppDatabase` 和 `FileStorageService` 各加一个可选构造参数用于注入。

**Tech Stack:** Flutter integration_test、drift（SQLite）、sqlite3、package:image（生成测试图片）、package:archive（解压校验导出 zip）。

**设计文档:** `docs/superpowers/specs/2026-08-05-integration-tests-design.md`

**运行环境:** Linux 桌面（`flutter test integration_test/<文件> -d linux`）。运行单个文件比全量快，每个测试文件都会完整编译/启动一次 app。注意：`ocr_test.dart` 为 Android-only（依赖 google_mlkit 插件），全量回归时需显式指定新测试文件，见 Task 7。

---

## 关键实施要点（执行前必读）

1. **`AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());`** — 注入测试 executor 时不会调用 `_openConnection()`（里面含 `applyWorkaroundToOpenSqlite3OnOldAndroidVersions`，仅 Android 用）。
2. **`FileStorageService({String? basePath})`** — 现有 `_basePath` 是 `String?` 私有字段，`basePath` getter 已处理懒初始化，加构造参数直接赋值即可。
3. **调度器坑**：`ParallelAnalysisScheduler.start()` 的 `_cleanupStuckJobs()` 会 `_aiQueueDao.deleteAll()` 清空 AI 队列。因此「导入后自动入队三类任务」的断言必须在**启动调度器之前**执行；启动调度器的测试只断言颜色分析完成。
4. **`MemeRepository.delete` 内部硬编码 `FileStorageService()`**（未注入），删除相关测试只断言 DB 层，不断言物理文件删除。
5. **`LogService.instance`** 未初始化时返回纯内存单例（不崩溃），调度器测试可直接传 `log: LogService.instance`。
6. 集成测试用 `testWidgets`（`IntegrationTestWidgetsFlutterBinding` 是 Live 绑定，真实异步 + 真实 Timer 均可工作）。
7. 测试图片用 `package:image` 运行时生成纯色 PNG，不依赖仓库路径。

## 文件结构

| 文件 | 责任 |
|---|---|
| `lib/core/database/database.dart` | 改：`AppDatabase` 支持注入 executor |
| `lib/services/file_storage_service.dart` | 改：`FileStorageService` 支持注入 basePath |
| `integration_test/test_env.dart` | 新建：测试环境（临时 db/存储/图片 + 组装服务） |
| `integration_test/import_flow_test.dart` | 新建：导入功能集成测试 |
| `integration_test/search_test.dart` | 新建：搜索功能集成测试 |
| `integration_test/album_test.dart` | 新建：相册功能集成测试 |
| `integration_test/export_test.dart` | 新建：导出功能集成测试 |
| `integration_test/analysis_queue_test.dart` | 新建：分析调度集成测试 |

---

## Task 1: 产品代码改动（可注入 executor / basePath）+ 测试环境

**Files:**
- Create: `integration_test/test_env.dart`
- Modify: `lib/core/database/database.dart:38-40`
- Modify: `lib/services/file_storage_service.dart:10-19`

- [ ] **Step 1: 编写测试环境 `integration_test/test_env.dart`**（依赖新构造参数，编译会失败）

```dart
import 'dart:io';

import 'package:drift/drift.dart' show QueryExecutor;
import 'package:drift/native.dart';
import 'package:image/image.dart' as img;
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/image/color_extractor.dart';
import 'package:mememaster/core/repositories/album_repository.dart';
import 'package:mememaster/core/repositories/color_repository.dart';
import 'package:mememaster/core/repositories/meme_repository.dart';
import 'package:mememaster/services/file_storage_service.dart';
import 'package:mememaster/services/import_service.dart';
import 'package:mememaster/services/meme_export_service.dart';
import 'package:mememaster/services/search_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// 集成测试环境：临时数据库 + 临时存储目录 + 真实服务。
///
/// 每次 create() 都新建独立临时目录，tearDown 时 dispose() 清理。
class TestEnv {
  late final Directory root;
  late final AppDatabase db;
  late final FileStorageService storage;
  late final MemeRepository memeRepo;
  late final AlbumRepository albumRepo;
  late final ColorExtractor colorExtractor;
  late final ImportService importService;
  late final SearchService searchService;
  late final MemeExportService exportService;

  String get srcDir => p.join(root.path, 'src');
  String get storageDir => p.join(root.path, 'storage');

  static Future<TestEnv> create() async {
    final env = TestEnv();
    env.root = await Directory.systemTemp.createTemp('meme_helper_it_');
    await Directory(env.srcDir).create(recursive: true);
    await Directory(env.storageDir).create(recursive: true);

    env.db = AppDatabase(
      NativeDatabase.opened(sqlite3.sqlite3.open(p.join(env.root.path, 'test.db'))),
    );
    env.storage = FileStorageService(basePath: env.storageDir);
    env.memeRepo = MemeRepository(
      memeDao: env.db.memeDao,
      tagDao: env.db.tagDao,
      colorDao: env.db.colorDao,
      queueDao: env.db.analysisQueueDao,
    );
    env.albumRepo = AlbumRepository(env.db.albumDao);
    env.colorExtractor = const ColorExtractor();
    env.importService = ImportService(
      memeRepo: env.memeRepo,
      storage: env.storage,
      userStatsDao: env.db.userStatsDao,
    );
    env.searchService = SearchService(
      memeRepo: env.memeRepo,
      colorRepo: ColorRepository(env.db.colorDao),
    );
    env.exportService = MemeExportService(
      memeRepo: env.memeRepo,
      storage: env.storage,
    );
    return env;
  }

  Future<void> dispose() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  }

  /// 生成一张纯色 PNG 测试图片，返回路径。
  Future<String> createImage({
    required String name,
    required List<int> rgb,
  }) async {
    final image = img.Image(width: 64, height: 64);
    img.fill(image, color: img.ColorRgb8(rgb[0], rgb[1], rgb[2]));
    final path = p.join(srcDir, name);
    await File(path).writeAsBytes(img.encodePng(image));
    return path;
  }
}
```

- [ ] **Step 2: 运行分析确认编译失败**

Run: `flutter analyze`
Expected: 报错 `lib/core/database/database.dart` 的 `AppDatabase` 没有接受 executor 参数的构造、`FileStorageService` 没有接受 `basePath` 的构造（或 test_env 中的调用行报错）。

- [ ] **Step 3: 修改 `AppDatabase` 支持注入 executor**

`lib/core/database/database.dart:39` 原代码：

```dart
  AppDatabase() : super(_openConnection());
```

改为：

```dart
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());
```

- [ ] **Step 4: 修改 `FileStorageService` 支持注入 basePath**

`lib/services/file_storage_service.dart:10-12` 原代码：

```dart
class FileStorageService {
  String? _basePath;
```

改为：

```dart
class FileStorageService {
  String? _basePath;

  FileStorageService({String? basePath}) : _basePath = basePath;
```

- [ ] **Step 5: 运行分析确认通过**

Run: `flutter analyze`
Expected: 无 error（原有 warning 忽略）。

- [ ] **Step 6: 运行既有单元测试确认无回归**

Run: `flutter test`
Expected: 全部通过（既有 mock 测试不受构造参数影响）。

- [ ] **Step 7: 提交**

```bash
git add lib/core/database/database.dart lib/services/file_storage_service.dart integration_test/test_env.dart
git commit -m "feat: 支持集成测试环境注入 executor/basePath，新增测试环境"
```

---

## Task 2: 导入图片集成测试

**Files:**
- Create: `integration_test/import_flow_test.dart`
- Test: 同上

- [ ] **Step 1: 编写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('成功导入图片入库并复制文件', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final result = await env.importService.importImages([path], source: '集成测试');

    expect(result.success, 1);
    expect(result.skipped, 0);
    expect(result.errors, isEmpty);

    final memes = await env.memeRepo.getAllSorted(sortField: 'imported_at');
    expect(memes.length, 1);
    expect(memes.first.filename, 'red.png');
    expect(memes.first.source, '集成测试');
    expect(memes.first.fileHash.length, 64);

    final stored = await env.storage.getImage(memes.first.filePath);
    expect(stored.existsSync(), true);
  });

  testWidgets('重复导入同一文件被哈希去重跳过', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final first = await env.importService.importImages([path]);
    expect(first.success, 1);

    final second = await env.importService.importImages([path]);
    expect(second.success, 0);
    expect(second.skipped, 1);
    expect(second.skippedFiles, contains('red.png'));

    expect(await env.memeRepo.count(), 1);
  });

  testWidgets('源文件不存在时跳过且不报错', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final result = await env.importService
        .importImages([p.join('/nonexistent', 'ghost.png')]);

    expect(result.success, 0);
    expect(result.skipped, 1);
    expect(result.errors, isEmpty);
    expect(result.skippedFiles, contains('ghost.png'));
    expect(await env.memeRepo.count(), 0);
  });

  testWidgets('批量导入多张图片全部成功', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final paths = <String>[
      await env.createImage(name: 'a.png', rgb: [255, 0, 0]),
      await env.createImage(name: 'b.png', rgb: [0, 255, 0]),
      await env.createImage(name: 'c.png', rgb: [0, 0, 255]),
    ];
    final result = await env.importService.importImages(paths);

    expect(result.success, 3);
    expect(result.errors, isEmpty);
    expect(await env.memeRepo.count(), 3);
  });
}
```

注意：需要 `import 'package:path/path.dart' as p;`（上面文件用到 `p.join`）。

- [ ] **Step 2: 运行测试**

Run: `flutter test integration_test/import_flow_test.dart -d linux`
Expected: 4 个用例全部通过（首次运行需等待 Linux 构建，可能几分钟）。

- [ ] **Step 3: 若失败，按失败信息修正（多为接口签名细节），重跑直至通过**

- [ ] **Step 4: 提交**

```bash
git add integration_test/import_flow_test.dart
git commit -m "test: 导入图片服务集成测试"
```

---

## Task 3: 搜索功能集成测试

**Files:**
- Create: `integration_test/search_test.dart`
- Test: 同上

- [ ] **Step 1: 编写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:mememaster/core/utils/color_utils.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('按文件名关键词搜索', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final cat = await env.createImage(name: 'cats_meme.png', rgb: [255, 0, 0]);
    final dog = await env.createImage(name: 'dogs_meme.png', rgb: [0, 255, 0]);
    await env.importService.importImages([cat, dog]);

    final results = await env.searchService.search(query: 'cats');
    expect(results.length, 1);
    expect(results.first.meme.filename, 'cats_meme.png');
  });

  testWidgets('按标签内容搜索', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    await env.db.tagDao.insert(TagEntry(
      id: 'tag_1',
      memeId: meme.id,
      source: 'ocr',
      content: '哈哈哈',
      confidence: 0.9,
    ));

    final results = await env.searchService.search(query: '哈哈');
    expect(results, isNotEmpty);
    expect(results.first.meme.id, meme.id);
  });

  testWidgets('按颜色搜索（提取主色保存后命中）', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    // 模拟调度器处理完颜色：提取主色并入库
    final imageFile = await env.storage.getImage(meme.filePath);
    final dominant = await env.colorExtractor.extract(imageFile.path);
    expect(dominant, isNotEmpty);
    await env.memeRepo.saveColors(dominant
        .map((c) => ColorEntry(
              id: '${meme.id}_${c.hex.replaceFirst('#', '')}',
              memeId: meme.id,
              hexColor: c.hex,
              labL: c.lChannel,
              labA: c.aChannel,
              labB: c.bChannel,
              ratio: c.ratio,
            ))
        .toList());

    final results =
        await env.searchService.search(colors: [const ColorRgb(255, 0, 0)]);
    expect(results, isNotEmpty);
    expect(results.first.meme.id, meme.id);
  });

  testWidgets('无查询条件时进入浏览模式', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);

    final results = await env.searchService.search();
    expect(results.length, 1);
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test integration_test/search_test.dart -d linux`
Expected: 4 个用例全部通过。

- [ ] **Step 3: 若失败，修正后重跑**

- [ ] **Step 4: 提交**

```bash
git add integration_test/search_test.dart
git commit -m "test: 搜索服务集成测试"
```

---

## Task 4: 相册功能集成测试

**Files:**
- Create: `integration_test/album_test.dart`
- Test: 同上

- [ ] **Step 1: 编写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('创建相册并加入图片', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemesToAlbum([meme.id], album.id);

    final ids = await env.albumRepo.getMemeIdsByAlbum(album.id);
    expect(ids, contains(meme.id));
    expect(await env.albumRepo.countMemesInAlbum(album.id), 1);
  });

  testWidgets('移出相册后计数归零', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemeToAlbum(meme.id, album.id);
    expect(await env.albumRepo.countMemesInAlbum(album.id), 1);

    await env.albumRepo.removeMemeFromAlbum(meme.id, album.id);
    expect(await env.albumRepo.countMemesInAlbum(album.id), 0);
  });

  testWidgets('按 meme 查询所属相册', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final album = await env.albumRepo.create(name: '表情包');
    await env.albumRepo.addMemeToAlbum(meme.id, album.id);

    final albumIds = await env.albumRepo.getAlbumIdsByMeme(meme.id);
    expect(albumIds, contains(album.id));
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test integration_test/album_test.dart -d linux`
Expected: 3 个用例全部通过。

- [ ] **Step 3: 若失败，修正后重跑**

- [ ] **Step 4: 提交**

```bash
git add integration_test/album_test.dart
git commit -m "test: 相册服务集成测试"
```

---

## Task 5: 导出功能集成测试

**Files:**
- Create: `integration_test/export_test.dart`
- Test: 同上

- [ ] **Step 1: 编写测试**

```dart
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('导出 zip 包含 manifest 与图片元数据', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final bytes = await env.exportService.exportMemesAsBytes(memeIds: [meme.id]);
    expect(bytes, isNotEmpty);

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = archive.files.map((f) => f.name).toList();
    expect(names, contains('manifest.json'));
    expect(names.any((n) => n.endsWith('.png')), isTrue);
    expect(names.any((n) => n.endsWith('.json')), isTrue);

    final manifestFile = archive.files.firstWhere((f) => f.name == 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    expect(manifest['count'], 1);
  });

  testWidgets('导出不存在的 id 时静默跳过', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final bytes = await env.exportService.exportMemesAsBytes(memeIds: ['no_such_id']);
    final archive = ZipDecoder().decodeBytes(bytes);
    final manifestFile = archive.files.firstWhere((f) => f.name == 'manifest.json');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    expect(manifest['count'], 0);
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test integration_test/export_test.dart -d linux`
Expected: 2 个用例全部通过。

- [ ] **Step 3: 若失败，修正后重跑**

- [ ] **Step 4: 提交**

```bash
git add integration_test/export_test.dart
git commit -m "test: 导出服务集成测试"
```

---

## Task 6: 分析调度集成测试

**Files:**
- Create: `integration_test/analysis_queue_test.dart`
- Test: 同上

- [ ] **Step 1: 编写测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mememaster/services/log_service.dart';
import 'package:mememaster/services/parallel_analysis_scheduler.dart';
import 'test_env.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('导入后自动入队三类分析任务', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    final result = await env.importService.importImages([path]);
    expect(result.success, 1);

    // 注意：必须先于启动调度器断言（调度器 start 会清空 AI 队列）
    expect(await env.db.colorAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.ocrAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.aiAnalysisQueueDao.getPendingCount(), 1);
  });

  testWidgets('启动调度器后颜色分析真实完成', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    final scheduler = ParallelAnalysisScheduler(
      colorQueueDao: env.db.colorAnalysisQueueDao,
      ocrQueueDao: env.db.ocrAnalysisQueueDao,
      aiQueueDao: env.db.aiAnalysisQueueDao,
      analysisQueueDao: env.db.analysisQueueDao,
      memeRepo: env.memeRepo,
      colorExtractor: env.colorExtractor,
      storage: env.storage,
      log: LogService.instance,
    );
    scheduler.setOcrEnabled(false);
    scheduler.start();
    addTearDown(scheduler.stop);

    // 轮询等待颜色分析完成（颜色调度器 1s 轮询一次）
    final deadline = DateTime.now().add(const Duration(seconds: 15));
    String? status;
    while (DateTime.now().isBefore(deadline)) {
      status = (await env.memeRepo.getById(meme.id))?.colorAnalysisStatus;
      if (status == 'done' || status == 'failed') break;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    expect(status, 'done', reason: '颜色分析应在 15s 超时前完成');
    expect(await env.memeRepo.getColors(meme.id), isNotEmpty);
  });

  testWidgets('reindexMeme 补缺失的分析维度', (tester) async {
    final env = await TestEnv.create();
    addTearDown(env.dispose);

    final path = await env.createImage(name: 'red.png', rgb: [255, 0, 0]);
    await env.importService.importImages([path]);
    final meme = (await env.memeRepo.getAllSorted(sortField: 'imported_at')).first;

    // 清空入队任务并模拟颜色已完成，使 OCR/AI 缺失
    await env.db.colorAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.db.ocrAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.db.aiAnalysisQueueDao.deleteByMemeId(meme.id);
    await env.memeRepo.updateColorAnalysisStatus(meme.id, 'done');

    final enqueued = await env.memeRepo.reindexMeme(meme.id);
    expect(enqueued, 2);
    expect(await env.db.colorAnalysisQueueDao.getPendingCount(), 0);
    expect(await env.db.ocrAnalysisQueueDao.getPendingCount(), 1);
    expect(await env.db.aiAnalysisQueueDao.getPendingCount(), 1);
  });
}
```

- [ ] **Step 2: 运行测试**

Run: `flutter test integration_test/analysis_queue_test.dart -d linux`
Expected: 3 个用例全部通过。

- [ ] **Step 3: 若失败，修正后重跑**

- [ ] **Step 4: 提交**

```bash
git add integration_test/analysis_queue_test.dart
git commit -m "test: 分析调度服务集成测试"
```

---

## Task 7: 全量回归验证

**Files:** 无新增

- [ ] **Step 1: 全量跑新集成测试**

注意：仓库内已有 `integration_test/ocr_test.dart`（Android-only，依赖 `google_mlkit_text_recognition` 插件且断言 `/sdcard/Download/ocr_test.jpg`），不能在 Linux 目录级全量跑。以下命令显式指定 5 个新测试文件：

Run: `flutter test integration_test/import_flow_test.dart integration_test/search_test.dart integration_test/album_test.dart integration_test/export_test.dart integration_test/analysis_queue_test.dart -d linux`
Expected: 全部用例通过（共 16 个：导入 4 + 搜索 4 + 相册 3 + 导出 2 + 调度 3）。

- [ ] **Step 2: 全量跑单元测试确认无回归**

Run: `flutter test`
Expected: 全部通过。

- [ ] **Step 3: 最终分析**

Run: `flutter analyze`
Expected: 无 error。

- [ ] **Step 4: 若第 1 步有失败，定位修正后重跑全量，直至全绿**

---

## 验收标准

1. 5 个新集成测试文件（16 个用例）在 Linux 全绿
2. `flutter test` 全绿（既有单元测试无回归）
3. `flutter analyze` 无 error
4. 产品代码改动仅限 2 个构造参数（`AppDatabase`、`FileStorageService`）
