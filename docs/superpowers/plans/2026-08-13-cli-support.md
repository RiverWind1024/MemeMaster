# MemeMaster CLI 支持实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 MemeMaster 添加纯 Dart CLI（`bin/mememaster.dart`），支持子命令式交互，完整覆盖核心功能，与 GUI 共用同一 SQLite 数据库。

**Architecture:** 复用 `lib/core` 与 `lib/services` 中纯 Dart 的引擎层（数据库/仓库/导入导出/搜索/颜色提取/ollama-openai），新增 `bin/mememaster.dart` 作为纯 Dart 入口（不 import flutter）。分两步解除 3 个 Flutter 依赖障碍点：`database.dart`（path_provider/sqlite3_flutter_libs → 注入 executor）、`s3_sync_service.dart`（flutter_secure_storage → 注入配置读写函数）。CLI 使用 `AppDatabase(NativeDatabase.opened(sqlite3.open(path)))` 打开与 GUI 相同的 `~/Documents/meme_helper.db`。

**Tech Stack:** Dart 3.12（pure Dart CLI via `dart run`）、drift + sqlite3、args 包、现有 `lib/core`/`lib/services` 复用。

---

## 背景与可行性结论

勘察结论（已验证）：

1. **核心引擎层几乎全是纯 Dart**，不依赖 Flutter：
   - `lib/core/database/`（drift + sqlite3）— 但 `database.dart:3-5` 顶层 import 了 `path_provider` 和 `sqlite3_flutter_libs`
   - `lib/core/repositories/`（meme/album/color repository）— 纯 Dart ✓
   - `lib/services/import_service.dart`、`search_service.dart`、`meme_export_service.dart`、`meme_import_service.dart`、`log_service.dart` — 纯 Dart ✓
   - `lib/core/image/color_extractor.dart` — 纯 Dart ✓
   - `lib/core/llm/ollama_service.dart`、`openai_service.dart` — 纯 Dart ✓
   - `lib/core/database/database.g.dart` — 无 flutter 依赖 ✓
2. **Flutter 依赖障碍点（必须解耦才能 `dart run`）**：
   - `lib/core/database/database.dart:3-5`：`import 'package:path_provider/path_provider.dart'` 和 `import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart'` → `dart run` 报 `dart:ui is not available`（已验证）
   - `lib/services/s3_sync_service.dart:5`：`import 'package:flutter_secure_storage/flutter_secure_storage.dart'`
   - `lib/core/llm/local_service.dart`、`vision_enricher.dart`、`ocr_service.dart`、`parallel_analysis_scheduler.dart`、`config_exporter.dart`：依赖 flutter/platform channel，**CLI 不复用**，用替代方案
3. **环境**：系统有 `libsqlite3.so`、`libtesseract.so.5.5`、`/usr/bin/tesseract`，Dart SDK 3.12.2，Flutter 4.6.2。

---

## 文件结构

**新增：**
```
bin/mememaster.dart                         # 纯 Dart 入口，解析子命令并分发
lib/cli/cli_app.dart                        # CLI 上下文组装（db + storage + repos + services）
lib/cli/command_parser.dart                 # 子命令定义与参数解析（args 包）
lib/cli/commands/import_command.dart        # import
lib/cli/commands/list_command.dart          # list
lib/cli/commands/get_command.dart           # get <id>
lib/cli/commands/search_command.dart        # search / search-color
lib/cli/commands/export_command.dart        # export
lib/cli/commands/tags_command.dart          # tags add/list/rm
lib/cli/commands/albums_command.dart        # albums list/create/rename/delete/add/rm
lib/cli/commands/s3_command.dart            # s3 sync/upload/download/test/stats
lib/cli/commands/reindex_command.dart       # reindex
lib/cli/commands/stats_command.dart         # stats
lib/cli/commands/config_command.dart        # config show/llm/s3
lib/cli/cli_repository_factory.dart         # 组装 repositories（集中管理）
lib/cli/cli_ocr.dart                        # CLI OCR：tesseract CLI 调用（纯 Dart）
lib/cli/cli_vision_analyzer.dart            # CLI AI 分析：ollama/openai + prompts 文件读取
lib/cli/commands/analyze_command.dart       # analyze（颜色+OCR+AI 单张/批量）
test/cli/cli_app_test.dart                  # 上下文组装测试
test/cli/import_command_test.dart
test/cli/search_command_test.dart
test/cli/tags_command_test.dart
test/cli/s3_config_command_test.dart
test/cli/ocr_test.dart                      # tesseract CLI 调用测试
```

**修改：**
- `lib/core/database/database.dart`：移除顶层 path_provider/sqlite3_flutter_libs import；`_openConnection()` 改为接受 `dbPath` 参数；新增 `AppDatabase.open(String dbPath)` 工厂
- `lib/services/s3_sync_service.dart`：移除顶层 flutter_secure_storage import；`clearAllData/setClearPassword/hasClearPassword` 改为通过构造注入的 `S3SecretStore` 接口（抽象类）访问
- `pubspec.yaml`：添加 `args: ^2.4.2`
- `lib/features/gallery/gallery_provider.dart`：`databaseProvider` 改传 `dbPath`（从 `storageDirProvider` 推导或新增 provider）；`s3SyncServiceProvider` 注入 `FlutterSecureStorageS3SecretStore`

---

## 任务 1：解耦 database.dart 的 Flutter 依赖

**Files:**
- Modify: `lib/core/database/database.dart:1-124`
- Modify: `lib/features/gallery/gallery_provider.dart:44`（`AppDatabase()` → `AppDatabase.open(dbPath)`）
- Modify: `lib/features/gallery/gallery_provider.dart:778` 附近（新增 `databasePathProvider`）
- Modify: `lib/app.dart:28`（注入 databasePath）
- Modify: `lib/main.dart`（Android workaround 移入 GUI）
- Test: `test/cli/database_open_test.dart`（新增）

背景：`database.dart` 顶层 import 了 `path_provider` 和 `sqlite3_flutter_libs`，纯 Dart CLI `dart run` 无法编译。`AppDatabase` 构造器已支持注入 `QueryExecutor`，只需把默认打开逻辑改为可注入路径。

- [ ] **Step 1: 写失败测试**

```dart
// test/cli/database_open_test.dart
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mememaster/core/database/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;
import 'package:path/path.dart' as p;

void main() {
  test('AppDatabase.open 使用指定路径打开 SQLite', () async {
    final dir = await Directory.systemTemp.createTemp('cli_db_test_');
    final dbPath = p.join(dir.path, 'meme_helper.db');

    final db = AppDatabase.open(dbPath);
    await db.into(db.memesTable).insert(
          MemesCompanion.insert(
            id: 'test-id',
            filename: 'a.png',
            filePath: '2026/08/a.png',
            fileSize: 1,
            mimeType: 'image/png',
            width: 10,
            height: 10,
            fileHash: 'hash',
          ),
        );
    final count = await db.memesTable.count().getSingle();
    expect(count, 1);

    await db.close();
    await dir.delete(recursive: true);
  });
}
```

注意：此测试是纯 Dart + drift，但用 `flutter_test` 包运行（因为项目测试都走 flutter test）。

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/cli/database_open_test.dart`
Expected: 编译错误 `AppDatabase.open` 不存在

- [ ] **Step 3: 实现 `AppDatabase.open`，彻底移除 path_provider 依赖**

修改 `lib/core/database/database.dart`：

```dart
// 移除两行顶层 import：
// import 'package:path_provider/path_provider.dart';
// import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// 打开指定路径的数据库（CLI/GUI 共用，不依赖 Flutter 插件）
  static AppDatabase open(String dbPath) {
    return AppDatabase(NativeDatabase.opened(
      sqlite3.sqlite3.open(dbPath, uri: false)
        ..execute('PRAGMA journal_mode=WAL')
        ..execute('PRAGMA foreign_keys=ON'),
    ));
  }
  ...
}

/// 默认连接（GUI 使用）：不再依赖 path_provider，
/// 数据库路径由调用方通过参数注入。
LazyDatabase _openConnection({String? dbPath}) {
  return LazyDatabase(() async {
    if (dbPath == null) {
      throw StateError('CLI 环境必须调用 AppDatabase.open(dbPath)，GUI 环境必须提供 dbPath');
    }
    final db = sqlite3.sqlite3.open(dbPath, uri: false)
      ..execute('PRAGMA journal_mode=WAL')
      ..execute('PRAGMA foreign_keys=ON');
    return NativeDatabase.opened(db);
  });
}
```

**结论（已确认）：** `_openConnection()`（database.dart:105-124）内部直接调用 `getApplicationDocumentsDirectory()` 和 `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()`，只要保留无参构造走默认连接，这两个顶层 import 就无法移除。因此必须**完全移除**，并同步修改 GUI 侧：

- **GUI 侧** `gallery_provider.dart:44`：`AppDatabase()` 改为 `AppDatabase.open(ref.read(databasePathProvider))`。
- 新增 `databasePathProvider`（`Provider<String>`，默认抛 `UnimplementedError`，仿照 `storageDirProvider` 模式），在 `app.dart:28` 由 `MemeManagerApp` 构造参数注入（`main.dart` 已算出 `docsDir`，传入 `'${docsDir.path}/meme_helper.db'`）。
- **Android workaround**：`applyWorkaroundToOpenSqlite3OnOldAndroidVersions()` 是 sqlite3_flutter_libs 提供的、Android 专用。移到 GUI 侧调用（`main.dart` 中在打开数据库前调用，或 `gallery_provider` 中 `AppDatabase.open` 之前条件调用 `if (Platform.isAndroid)`）。CLI（Linux）不需要。

GUI 数据库路径保持不变：`~/Documents/meme_helper.db`（`main.dart` 已算 `docsDir`），CLI 默认也用此路径，二者共用。

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/cli/database_open_test.dart`
Expected: PASS

- [ ] **Step 5: 回归 GUI 测试**

Run: `flutter test test/` （确保现有测试不依赖被改动的打开逻辑，或改用 `AppDatabase.open` 注入临时路径）
Expected: 全部通过（如失败，把测试中 `AppDatabase()` 调用改为注入临时 dbPath）

- [ ] **Step 6: Commit**

```bash
git add lib/core/database/database.dart test/cli/database_open_test.dart
git commit -m "refactor(db): AppDatabase.open 支持指定路径，解除 CLI 对 Flutter 插件的依赖"
```

---

## 任务 2：解耦 s3_sync_service.dart 的 secure_storage 依赖

**Files:**
- Modify: `lib/services/s3_sync_service.dart:279-318`（clearAllData/setClearPassword/hasClearPassword）
- Modify: `lib/features/gallery/gallery_provider.dart`（s3SyncServiceProvider 注入存储实现）
- Add: `lib/cli/cli_s3_secret_store.dart`（CLI 用文件/内存存储）
- Test: `test/cli/s3_config_command_test.dart`

背景：`s3_sync_service.dart` 顶层 import `flutter_secure_storage`，仅用于 `clearAllData`/`setClearPassword`/`hasClearPassword` 三个方法读写密码。CLI 不需要 FlutterSecureStorage，用文件或内存存储即可。

- [ ] **Step 1: 定义抽象接口**

在 `lib/services/s3_sync_service.dart` 顶部（或独立文件）新增：

```dart
/// S3 清空密码存储抽象（GUI 用 FlutterSecureStorage，CLI 用文件存储）
abstract class S3SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
```

将 `clearAllData`/`setClearPassword`/`hasClearPassword` 中的 `const FlutterSecureStorage()` 替换为 `_secretStore` 字段。

`S3SyncService` 构造器新增：

```dart
S3SyncService({
  ...,
  required S3SecretStore secretStore,
}) : _secretStore = secretStore;
```

- [ ] **Step 2: 更新 GUI 注入**

在 `lib/features/gallery/gallery_provider.dart` 的 `s3SyncServiceProvider` 中传入基于 FlutterSecureStorage 的 `S3SecretStore` 实现（新建 `lib/services/s3_secret_store_flutter.dart` 或内联）。

- [ ] **Step 3: 写测试**

`test/cli/s3_config_command_test.dart`：用内存版 S3SecretStore，验证 CLI 可设置/读取 S3 配置，且无需 Flutter 插件。

- [ ] **Step 4: 运行测试**

Run: `flutter test test/cli/s3_config_command_test.dart test/services/s3_config_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/services/s3_sync_service.dart lib/features/gallery/gallery_provider.dart lib/cli/
git commit -m "refactor(s3): S3SecretStore 抽象，解除 CLI 对 flutter_secure_storage 的依赖"
```

---

## 任务 3：CLI 骨架（入口 + 上下文 + 子命令分发）

**Files:**
- Create: `bin/mememaster.dart`
- Create: `lib/cli/cli_app.dart`
- Create: `lib/cli/command_parser.dart`
- Modify: `pubspec.yaml`（添加 `args: ^2.4.2`）
- Test: `test/cli/cli_app_test.dart`

- [ ] **Step 1: 添加 args 依赖**

```yaml
dependencies:
  args: ^2.4.2
```

Run: `flutter pub get`

- [ ] **Step 2: 写失败测试**

`test/cli/cli_app_test.dart`：验证 `CliApp` 能正确解析子命令并路由。

```dart
// 示例：验证 list 子命令可执行（使用临时 db）
```

- [ ] **Step 3: 实现 CLI 入口与解析**

`bin/mememaster.dart`（纯 Dart，不 import flutter）：

```dart
import 'dart:io';
import 'package:args/args.dart';
import 'package:mememaster/cli/cli_app.dart';

Future<void> main(List<String> args) async {
  exitCode = await CliApp().run(args);
}
```

`lib/cli/cli_app.dart`：
- 定义所有子命令（import/list/get/search/export/tags/albums/s3/reindex/stats/config/analyze/help）
- 用 `args` 包定义全局参数：`--db`（数据库路径，默认 `~/Documents/meme_helper.db`）、`--storage`（文件存储根目录，默认 `~/Documents/memes`）、`--json`（JSON 输出）
- 组装 `AppDatabase.open(dbPath)`、`FileStorageService(basePath:)`、`MemeRepository`、`ImportService`、`SearchService`、`MemeExportService` 等
- 分发到各 command

- [ ] **Step 4: 冒烟测试**

Run: `dart run bin/mememaster.dart list`
Expected: 输出空列表或现有数据库内容，退出码 0

Run: `dart run bin/mememaster.dart --help`
Expected: 打印帮助

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml pubspec.lock bin/mememaster.dart lib/cli/ test/cli/
git commit -m "feat(cli): 纯 Dart CLI 骨架，支持 --db/--storage 与子命令分发"
```

---

## 任务 4：import / list / get 命令

**Files:**
- Create: `lib/cli/commands/import_command.dart`
- Create: `lib/cli/commands/list_command.dart`
- Create: `lib/cli/commands/get_command.dart`
- Test: `test/cli/import_command_test.dart`

- [ ] **Step 1: 写失败测试**

`import_command_test.dart`：导入一张测试 PNG 到临时库，验证 DB 中出现该 meme、文件被复制到 storage 目录、分析入队。

- [ ] **Step 2: 实现 import_command**

复用 `ImportService.importImages(paths)`，输出每张图片的导入结果（成功/跳过/错误）。支持参数：`<paths...>`、`--source`、`--recursive`（递归扫描目录）、`--output-json`。

- [ ] **Step 3: 实现 list_command**

复用 `MemeRepository.getAll()`，输出表格（id 短码、文件名、尺寸、导入时间、分析状态）或 `--json`。

- [ ] **Step 4: 实现 get_command**

`get <id>`：输出 meme 详情 + 标签 + 颜色。

- [ ] **Step 5: 运行测试 + 冒烟**

Run: `flutter test test/cli/import_command_test.dart`
Run: `dart run bin/mememaster.dart import ./test/img/xxx.png`
Run: `dart run bin/mememaster.dart list`

Expected: 导入成功，列表可见

- [ ] **Step 6: Commit**

```bash
git add lib/cli/commands/ test/cli/
git commit -m "feat(cli): import/list/get 子命令"
```

---

## 任务 5：search / search-color 命令

**Files:**
- Create: `lib/cli/commands/search_command.dart`
- Test: `test/cli/search_command_test.dart`

- [ ] **Step 1: 写失败测试**

准备带标签/颜色的临时库，验证关键词搜索和颜色搜索返回正确结果。

- [ ] **Step 2: 实现 search**

`search <query> [--color #RRGGBB] [--limit N]`，复用 `SearchService.search()`（已实现文本关键词 + 颜色 + 合并排序）。CLI 用纯 Dart 实现 `ColorRgb` 解析。

- [ ] **Step 3: 运行测试 + 冒烟**

Run: `flutter test test/cli/search_command_test.dart`
Run: `dart run bin/mememaster.dart search 猫`
Run: `dart run bin/mememaster.dart search --color #ff0000`

- [ ] **Step 4: Commit**

```bash
git add lib/cli/commands/search_command.dart test/cli/
git commit -m "feat(cli): search/search-color 子命令"
```

---

## 任务 6：export / tags / albums 命令

**Files:**
- Create: `lib/cli/commands/export_command.dart`
- Create: `lib/cli/commands/tags_command.dart`
- Create: `lib/cli/commands/albums_command.dart`
- Test: `test/cli/tags_command_test.dart`

- [ ] **Step 1: 写失败测试**

tags：给 meme 添加/删除/列出自定义标签。albums：创建/重命名/加 meme 到相册。

- [ ] **Step 2: 实现 export**

`export [--ids id1,id2 | --all] --output out.zip`，复用 `MemeExportService.exportMemes()`。

- [ ] **Step 3: 实现 tags**

`tags add <memeId> <tag> [--source custom]`、`tags rm <memeId> <tag>`、`tags list <memeId>`。复用 `MemeRepository.saveTags/deleteTags/getTags`。

- [ ] **Step 4: 实现 albums**

`albums list`、`albums create <name>`、`albums rename <id> <name>`、`albums delete <id>`、`albums add <memeId> <albumId>`、`albums rm <memeId> <albumId>`。复用 `AlbumRepository`。

- [ ] **Step 5: 运行测试 + 冒烟**

Run: `flutter test test/cli/tags_command_test.dart`
Run: `dart run bin/mememaster.dart tags list <id>`

- [ ] **Step 6: Commit**

```bash
git add lib/cli/commands/ test/cli/
git commit -m "feat(cli): export/tags/albums 子命令"
```

---

## 任务 7：analyze 命令（颜色 + OCR + AI）

**Files:**
- Create: `lib/cli/cli_ocr.dart`（tesseract CLI 调用，纯 Dart）
- Create: `lib/cli/cli_vision_analyzer.dart`（复用 OllamaLlmService/OpenAiLlmService + prompts 文件读取）
- Create: `lib/cli/commands/analyze_command.dart`
- Test: `test/cli/ocr_test.dart`

背景：GUI 的 `ocr_service.dart`/`vision_enricher.dart` 依赖 flutter，CLI 不复用。CLI 用系统 tesseract CLI + ollama/openai 远程服务实现同等能力。注意 `assets/prompts/*.txt` 需通过 `File` 读取（GUI 用 rootBundle，CLI 用相对路径 `assets/prompts/`）。

- [ ] **Step 1: 写失败测试（OCR）**

`ocr_test.dart`：用 `cli_ocr.dart` 识别一张含文字的 PNG（从 test/fixtures 读取或生成），验证返回文本非空。系统已装 tesseract 5.5.2。

- [ ] **Step 2: 实现 cli_ocr.dart**

```dart
class CliOcr {
  Future<String> recognize(String imagePath) async {
    final result = await Process.run(
      'tesseract', ['$imagePath', 'stdout', '-l', 'chi_sim+eng', '--psm', '3'],
    );
    return result.stdout.toString().trim();
  }
}
```

（语言参数可配置，默认 chi_sim+eng；如无 chi_sim 语言包则降级 eng。）

- [ ] **Step 3: 实现 cli_vision_analyzer.dart**

读取 `assets/prompts/vision_system_zh.txt`/`vision_user_zh.txt`，调用 Ollama（默认 localhost:11434）或 OpenAI。返回描述文本。复用 `LlmConfig`、`LlmMessage`。

- [ ] **Step 4: 实现 analyze_command**

`analyze <memeId... | --all> [--color|--ocr|--ai]`：
- `--color`：用 `ColorExtractor` 提取主色，写入 colors 表，更新 `colorAnalysisStatus`
- `--ocr`：用 `CliOcr` 识别，写入 tags（source=ocr）+ description
- `--ai`：用 `CliVisionAnalyzer`，写入 tags（source=llm）+ description，更新 `aiAnalysisStatus`
- 更新 `analysisStatus`/各维度状态；复用 `MemeRepository.updateXxxStatus`

- [ ] **Step 5: 运行测试 + 冒烟**

Run: `flutter test test/cli/ocr_test.dart`
Run: `dart run bin/mememaster.dart analyze <id> --color --ocr --ai`（需 ollama 可用；无 ollama 时 --ai 报错提示配置）

- [ ] **Step 6: Commit**

```bash
git add lib/cli/ test/cli/
git commit -m "feat(cli): analyze 命令（颜色+OCR+AI），纯 Dart tesseract/ollama 集成"
```

---

## 任务 8：s3 / reindex / stats / config 命令

**Files:**
- Create: `lib/cli/commands/s3_command.dart`
- Create: `lib/cli/commands/reindex_command.dart`
- Create: `lib/cli/commands/stats_command.dart`
- Create: `lib/cli/commands/config_command.dart`
- Test: `test/cli/s3_config_command_test.dart`（补充）

- [ ] **Step 1: 实现 config_command**

`config show`、`config llm --base-url --model --provider --api-key`、`config s3 --endpoint --bucket --access-key --secret-key`。S3 配置存到 CLI 自己的配置文件（`~/.config/mememaster/cli_config.json`）或直接内存（每命令传参）。LLM 配置用于 analyze 的 AI 部分。

- [ ] **Step 2: 实现 s3_command**

`s3 upload|download|sync|test|stats`，复用 `S3SyncService`（上传/下载/增量同步），构造时注入 CLI 版 S3SecretStore 和 S3Config。进度回调打印到 stdout。

- [ ] **Step 3: 实现 reindex_command**

`reindex <memeId... | --all>`，复用 `MemeRepository.reindexMeme/reindexAll`。

- [ ] **Step 4: 实现 stats_command**

`stats`：复用 `MemeRepository.count()`、各状态计数、`FileStorageService.storageUsed()`，输出统计。

- [ ] **Step 5: 运行测试 + 冒烟**

Run: `flutter test test/cli/s3_config_command_test.dart`
Run: `dart run bin/mememaster.dart stats`
Run: `dart run bin/mememaster.dart config show`

- [ ] **Step 6: Commit**

```bash
git add lib/cli/commands/ test/cli/
git commit -m "feat(cli): s3/reindex/stats/config 子命令"
```

---

## 任务 9：回归验证 + 文档

**Files:**
- Modify: `README.md`（CLI 用法章节）
- Modify: `docs/USAGE.md`（CLI 说明）

- [ ] **Step 1: 完整测试**

Run: `flutter analyze`
Expected: 无 error/warning（新增代码）

Run: `flutter test test/`
Expected: 全部通过

- [ ] **Step 2: CLI 全命令冒烟**

Run:
```bash
dart run bin/mememaster.dart --help
dart run bin/mememaster.dart import ./test/img/*.png
dart run bin/mememaster.dart list
dart run bin/mememaster.dart search 猫
dart run bin/mememaster.dart stats
dart run bin/mememaster.dart config show
```
Expected: 全部正常输出，退出码 0

- [ ] **Step 3: 验证 GUI 未被破坏**

Run: `flutter run -d linux`（或 `flutter build linux --debug`）
Expected: 正常编译启动

- [ ] **Step 4: 更新文档**

README/USAGE 增加 CLI 章节：安装、常用命令、与 GUI 共用数据库说明。

- [ ] **Step 5: Commit**

```bash
git add README.md docs/USAGE.md
git commit -m "docs: 新增 CLI 用法文档"
```

---

## 风险与注意事项

1. **`AppDatabase()` 无参构造**被 GUI（`gallery_provider.dart:44`）使用，且 `_openConnection()` 内部依赖 path_provider + Android workaround（已验证，database.dart:105-124）。**方案（已确认）：彻底移除这两个顶层 import**，GUI 改为通过 `databasePathProvider` 注入 dbPath，Android workaround 移到 GUI 侧。GUI 数据库路径保持 `~/Documents/meme_helper.db` 不变。
2. **测试框架**：项目用 `flutter test`（`test/` 下已有纯 Dart 逻辑测试，如 `file_storage_service_test.dart`），CLI 测试沿用。
3. **tesseract 语言包**：`chi_sim` 可能未安装，OCR 测试需 fallback（先 `tesseract --list-langs` 检测，缺失则用 `eng`）。
4. **ollama 默认不可用**：analyze `--ai` 在无 ollama 时报错并提示 `config llm` 配置，不阻塞其他命令。
5. **CLI 默认 db 路径**：`~/Documents/meme_helper.db`（与 GUI 一致）。提供 `--db` 覆盖。若 db 不存在，`AppDatabase.open` 会创建空库；CLI 首次运行会建立 schema（含默认"所有图片"相册）。
