# 服务层集成测试套件设计

日期：2026-08-05

## 背景

项目需要一个集成测试套件，覆盖各功能模块。不模拟完整 UI 操作路径（点击 FAB → 导入图片 → 原生文件对话框），
而是直接调用服务层函数，以"函数调用成功 + 数据落地正确"作为测试通过标准。

运行环境：Linux 桌面（`flutter test integration_test -d linux`）。

## 方案

纯服务层直调（不启动 UI、不经过 Riverpod ProviderContainer）：

- 测试内直接 `new` 出被测服务（`ImportService`、`SearchService`、`MemeExportService`、`AlbumRepository`、`ParallelAnalysisScheduler`）
- 底层依赖注入真实的临时数据库 + 临时图片目录，验证真实的数据流（文件复制、SQL 写入、zip 编码、分析队列处理）

### 产品代码改动（2 处，最小侵入）

1. `lib/core/database/database.dart`
   - `AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());`
   - 允许测试注入自定义 executor（临时文件或 `:memory:` 数据库）

2. `lib/services/file_storage_service.dart`
   - `FileStorageService({String? basePath})`
   - 注入测试存储目录，否则懒加载 `getApplicationDocumentsDirectory()`

## 测试基础设施

`integration_test/test_env.dart`：

- 每次测试创建临时目录（db 文件、图片存储目录、源图片目录），tearDown 清理
- 用 `package:image` 运行时生成不同颜色的测试 PNG（尺寸/内容可控，用于去重、颜色搜索、导出校验）
- 组装服务：`AppDatabase(executor)` → `MemeRepository` / `UserStatsDao` → 各被测服务

## 功能点测试清单

| 模块 | 文件 | 用例 |
|---|---|---|
| 导入 | `import_flow_test.dart` | 成功导入入库、重复导入跳过（哈希去重）、源文件不存在跳过、批量导入计数、文件复制到存储目录 |
| 搜索 | `search_test.dart` | 按文件名搜索、按标签搜索、按颜色搜索、浏览模式 |
| 相册 | `album_test.dart` | 创建相册、加图片到相册、按相册查图片、移出相册 |
| 导出 | `export_test.dart` | 导出 zip 字节、可解压、含 manifest.json + 图片 + 元数据 json |
| 分析调度 | `analysis_queue_test.dart` | 导入后自动入队颜色/OCR/AI 任务、启动调度器后颜色分析完成（状态→done）、reindexMeme 补缺 |

## 已知注意点

- `MemeRepository.delete` 内部硬编码 `FileStorageService()`（未注入），物理文件删除无法验证，删除测试只断言 DB 层（软删除）。此为既有代码问题，本次不改。
- 分析调度测试：OCR 设为关闭（避免依赖 tesseract），AI 无 LLM 默认不执行；只验证颜色分析真实跑完。
- 测试图片运行时生成，不依赖仓库内 `test/img/` 路径。

## 验证方式

`flutter test integration_test/<测试文件> -d linux` 逐个或批量运行新测试文件全部通过。
注意：仓库内已有 `integration_test/ocr_test.dart` 为 Android-only（依赖 `google_mlkit_text_recognition` 插件），不能在 Linux 目录级全量跑，需显式指定新文件。
