# S3 云同步实施计划

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现完整的 S3 双向同步系统，覆盖元数据上传/下载、增量同步、存储统计、数据清空。

**Architecture:** 在现有 `S3SyncService` 基础上重写，新增 `S3SyncSerializer` 处理数据序列化、`SyncStateDao` 管理同步状态。同步页面从设置页的 Card 升级为独立路由。增量同步基于 `updatedAt` 时间戳对比实现 last-write-wins 冲突策略。

**Tech Stack:** minio 3.5.8 (S3 客户端), flutter_secure_storage (密钥加密), drift (SyncStateTable), shared_preferences (配置持久化)

**设计文档:** `docs/superpowers/specs/2026-07-01-s3-sync-design.md`

---

## Chunk 1: 基础设施

### Task 1.1: 创建 SyncStateDao

> 为已有的 `SyncStateTable` 提供 DAO 操作，管理 `last_sync_at` / `last_snapshot_version` / `last_pull_at` 三个 key。

**Files:**
- Create: `lib/core/database/daos/sync_state_dao.dart`
- Modify: `lib/core/database/database.dart` (注册 DAO)

- [ ] **Step 1: 创建 SyncStateDao**

```dart
// lib/core/database/daos/sync_state_dao.dart
import 'package:drift/drift.dart';
import '../database.dart';
import '../tables/sync_state_table.dart';

class SyncStateDao {
  final AppDatabase _db;
  SyncStateDao(this._db);

  Future<String?> get(String id) async {
    final row = await (_db.select(_db.syncStateTable)
      ..where((t) => t.id.equals(id)))
      .getSingleOrNull();
    return row?.value;
  }

  Future<void> set(String id, String value) async {
    await _db.into(_db.syncStateTable).insertOnConflictUpdate(
      SyncStateEntry(id: id, value: value, updatedAt: DateTime.now().millisecondsSinceEpoch),
    );
  }

  Future<int?> getLastSyncAt() async {
    final v = await get('last_sync_at');
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setLastSyncAt(int timestamp) =>
      set('last_sync_at', timestamp.toString());

  Future<int?> getLastSnapshotVersion() async {
    final v = await get('last_snapshot_version');
    return v != null ? int.tryParse(v) : null;
  }

  Future<void> setLastSnapshotVersion(int version) =>
      set('last_snapshot_version', version.toString());

  Future<void> reset() async {
    await (_db.delete(_db.syncStateTable)).go();
  }
}
```

- [ ] **Step 2: 在 AppDatabase 中注册**

```dart
// lib/core/database/database.dart
// 在 class AppDatabase 内新增:
late final SyncStateDao syncStateDao = SyncStateDao(this);
```

- [ ] **Step 3: 验证编译通过**

Run: `dart analyze lib/core/database/` 或 `flutter analyze lib/core/database/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/core/database/daos/sync_state_dao.dart lib/core/database/database.dart
git commit -m "feat: add SyncStateDao for sync state tracking"
```

---

### Task 1.2: 创建 S3SyncSerializer

> 负责将 meme 及其关联数据（tags、colors、albums）序列化为 JSON，以及从 JSON 反序列化恢复到数据库。与 S3SyncService 解耦，可独立测试。

**Files:**
- Create: `lib/services/s3_sync_serializer.dart`
- Test: `test/services/s3_sync_serializer_test.dart`

- [ ] **Step 1: 定义序列化数据模型和接口**

```dart
// lib/services/s3_sync_serializer.dart
import 'dart:convert';
import '../core/repositories/meme_repository.dart';
import '../core/repositories/album_repository.dart';
import '../core/database/daos/color_dao.dart';
import '../core/database/daos/tag_dao.dart';
import '../core/database/database.dart';

/// 单条 meme 的完整可传输数据（含子资源）
class MemeSyncData {
  final Meme meme;
  final List<TagEntry> tags;
  final List<ColorEntry> colors;

  MemeSyncData({required this.meme, required this.tags, required this.colors});

  Map<String, dynamic> toJson() => {
    'id': meme.id,
    'filename': meme.filename,
    'filePath': meme.filePath,
    'fileHash': meme.fileHash,
    'fileSize': meme.fileSize,
    'mimeType': meme.mimeType,
    'width': meme.width,
    'height': meme.height,
    'description': meme.description,
    'analysisStatus': meme.analysisStatus,
    'createdAt': meme.createdAt,
    'updatedAt': meme.updatedAt,
    'tags': tags.map((t) => {
      'source': t.source,
      'content': t.content,
      'confidence': t.confidence,
    }).toList(),
    'colors': colors.map((c) => {
      'hexColor': c.hexColor,
      'labL': c.labL,
      'labA': c.labA,
      'labB': c.labB,
      'ratio': c.ratio,
    }).toList(),
  };
}

/// 全量同步数据：所有 memes + 所有 albums + 关联
class FullSyncData {
  final List<MemeSyncData> memes;
  final List<Album> albums;
  final List<MemeAlbum> memeAlbums;
  final int version;
  final int exportedAt;

  FullSyncData({
    required this.memes,
    required this.albums,
    required this.memeAlbums,
    required this.version,
    required this.exportedAt,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'exportedAt': exportedAt,
    'memes': memes.map((m) => m.toJson()).toList(),
    'albums': albums.map((a) => {
      'id': a.id,
      'name': a.name,
      'icon': a.icon,
      'sortOrder': a.sortOrder,
      'createdAt': a.createdAt,
    }).toList(),
    'memeAlbums': memeAlbums.map((ma) => {
      'memeId': ma.memeId,
      'albumId': ma.albumId,
      'addedAt': ma.addedAt,
    }).toList(),
  };

  String toJsonString() => jsonEncode(toJson());
}

class S3SyncSerializer {
  final MemeRepository _memeRepo;
  final AlbumRepository _albumRepo;

  S3SyncSerializer({
    required MemeRepository memeRepo,
    required AlbumRepository albumRepo,
  }) : _memeRepo = memeRepo,
       _albumRepo = albumRepo;

  /// 导出全量数据
  Future<FullSyncData> exportFull(int version) async {
    final memes = await _memeRepo.getAll();
    final memesWithData = await Future.wait(memes.map((m) => _exportMeme(m)));
    final albums = await _albumRepo.getAll();
    final memeAlbums = await _albumRepo.getAllMemeAlbums();
    return FullSyncData(
      memes: memesWithData,
      albums: albums,
      memeAlbums: memeAlbums,
      version: version,
      exportedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<MemeSyncData> _exportMeme(Meme meme) async {
    final tags = await _memeRepo.getTags(meme.id);
    final colors = await _memeRepo.getColors(meme.id);
    return MemeSyncData(meme: meme, tags: tags, colors: colors);
  }

  /// 导入（恢复）全量数据到本地数据库
  Future<void> importFull(FullSyncData data) async {
    // 按顺序写：先清理 → albums → memes → memeAlbums → tags → colors
    // 在事务中执行
  }
}
```

- [ ] **Step 2: 编写单元测试**

```dart
// test/services/s3_sync_serializer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// ... test serialization round-trip
```

- [ ] **Step 3: 运行测试**

Run: `flutter test test/services/s3_sync_serializer_test.dart -v`
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add lib/services/s3_sync_serializer.dart test/services/s3_sync_serializer_test.dart
git commit -m "feat: add S3SyncSerializer for data serialization"
```

---

### Task 1.3: S3Config 增强 + 密钥安全存储

> 当前 secretKey 明文存在 SharedPreferences 中，迁移到 flutter_secure_storage。S3Config 增加 pathStyle 和 connectTimeout 字段。

**Files:**
- Modify: `lib/services/s3_config.dart` (新增字段)
- Modify: `lib/features/gallery/gallery_provider.dart` (S3ConfigNotifier 改为 AsyncNotifier)

- [ ] **Step 1: S3Config 新增字段**

```dart
// lib/services/s3_config.dart
class S3Config {
  // ... 现有字段不变，新增：
  final bool pathStyle;      // true = path-style (s3.amazonaws.com/bucket), false = virtual-hosted
  final int connectTimeout;  // 连接超时（秒）

  // toJson / fromJson / copyWith 同步更新
}
```

- [ ] **Step 2: S3ConfigNotifier 改为 AsyncNotifier 并使用 FlutterSecureStorage**

```dart
// lib/features/gallery/gallery_provider.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class S3ConfigNotifier extends AsyncNotifier<S3Config> {
  @override
  Future<S3Config> build() async {
    final storage = const FlutterSecureStorage();
    try {
      return S3Config(
        endpoint: await storage.read(key: 's3_endpoint') ?? '',
        bucket: await storage.read(key: 's3_bucket') ?? '',
        region: await storage.read(key: 's3_region') ?? 'us-east-1',
        accessKey: await storage.read(key: 's3_access_key') ?? '',
        secretKey: await storage.read(key: 's3_secret_key') ?? '',
        useSsl: true,
      );
    } catch (_) {
      return const S3Config();
    }
  }

  Future<void> update(S3Config config) async {
    state = AsyncData(config);
    final storage = const FlutterSecureStorage();
    await Future.wait([
      storage.write(key: 's3_endpoint', value: config.endpoint),
      storage.write(key: 's3_bucket', value: config.bucket),
      storage.write(key: 's3_region', value: config.region),
      storage.write(key: 's3_access_key', value: config.accessKey),
      storage.write(key: 's3_secret_key', value: config.secretKey),
    ]);
  }
}

// Provider 声明改为 AsyncNotifierProvider
final s3ConfigProvider = AsyncNotifierProvider<S3ConfigNotifier, S3Config>(
  S3ConfigNotifier.new,
);
```

- [ ] **Step 3: 修复 `s3SyncServiceProvider` 中对 `s3ConfigProvider` 的引用（async 适配）**

```dart
// s3SyncServiceProvider 中:
service.updateConfig(ref.read(s3ConfigProvider).valueOrNull ?? const S3Config());
```

- [ ] **Step 4: 验证编译 + 分析**

Run: `dart analyze lib/`
Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git add lib/services/s3_config.dart lib/features/gallery/gallery_provider.dart
git commit -m "feat: migrate S3 config to secure storage, add pathStyle/connectTimeout"
```

---

## Chunk 2: 核心同步逻辑

### Task 2.1: 重写 S3SyncService — 连通性测试 + 全量上传

> 重写 `S3SyncService`，实现 `testConnection()` 和全量版本的 `uploadAll()`（图片 + 元数据 JSON + 全量快照）。保留原始 `uploadAll()` 的 Stream 进度接口不变。

**Files:**
- Modify: `lib/services/s3_sync_service.dart` (重写)
- Modify: `lib/features/gallery/gallery_provider.dart` (注入 SyncStateDao + S3SyncSerializer)

- [ ] **Step 1: S3SyncService 新接口定义和构造注入**

```dart
// lib/services/s3_sync_service.dart
class S3SyncService {
  final MemeRepository _memeRepo;
  final AlbumRepository _albumRepo;
  final FileStorageService _storage;
  final SyncStateDao _syncStateDao;
  final S3SyncSerializer _serializer;
  S3Config _config = const S3Config();
  Minio? _client;
  bool _cancelled = false;

  S3SyncService({
    required MemeRepository memeRepo,
    required AlbumRepository albumRepo,
    required FileStorageService storage,
    required SyncStateDao syncStateDao,
    required S3SyncSerializer serializer,
  }) : _memeRepo = memeRepo,
       _albumRepo = albumRepo,
       _storage = storage,
       _syncStateDao = syncStateDao,
       _serializer = serializer;
```

- [ ] **Step 2: 实现 testConnection()**

```dart
  Future<bool> testConnection() async {
    try {
      final client = _getClient();
      await client.listBuckets();
      try {
        await client.headBucket(_config.bucket);
      } catch (_) {
        // bucket 可能不存在，但能连上 S3 就算连接成功
      }
      return true;
    } catch (e) {
      return false;
    }
  }
```

- [ ] **Step 3: 实现 _ensureBucket() + 全量 uploadAll()**

```dart
  /// 确保 bucket 存在（不存在则创建）
  Future<void> _ensureBucket() async {
    try {
      await _getClient().headBucket(_config.bucket);
    } catch (e) {
      // bucket 不存在，尝试创建
      await _getClient().makeBucket(_config.bucket, _config.region);
    }
  }

  /// 全量上传：图片 + 元数据 JSON + 快照
  Stream<SyncProgress> uploadAll() async* {
    if (!isConfigured) { /* yield error */ return; }
    _cancelled = false;

    // 1. 确保 bucket 存在
    await _ensureBucket();

    // 2. 导出全量数据
    final snapshot = await _serializer.exportFull(1);
    final totalSteps = snapshot.memes.length + 3; // memes + memes.json + albums.json + snapshot.json

    // 3. 上传 JSON
    yield SyncProgress(status: SyncStatus.uploading, completed: 0, total: totalSteps);

    // 上传 memes.json
    await _uploadJson('data/memes.json', snapshot.memes.map((m) => m.toJson()).toList());
    // 上传 albums.json
    await _uploadJson('data/albums.json', snapshot.albums.map(...));
    // 上传 snapshot
    await _uploadJson('snapshot-v1.json', snapshot.toJson());

    var completed = 3;
    for (final memeData in snapshot.memes) {
      if (_cancelled) { /* yield cancelled */ return; }

      // 4. 上传图片（跳过已存在的）
      try {
        await _uploadImageIfNeeded(memeData.meme);
      } catch (e) {
        yield SyncProgress(status: SyncStatus.error, completed: completed, total: totalSteps,
            errorMessage: '图片上传失败: ${memeData.meme.filename}: $e');
        // 不 return，继续传下一张
        completed++;
        continue;
      }
      completed++;
      yield SyncProgress(status: SyncStatus.uploading, completed: completed, total: totalSteps);
    }

    // 5. 更新同步状态
    await _syncStateDao.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);

    yield SyncProgress(status: SyncStatus.idle, completed: completed, total: totalSteps);
  }
```

- [ ] **Step 4: 实现辅助方法**

```dart
  Future<void> _uploadJson(String key, dynamic data) async {
    final jsonStr = jsonEncode(data);
    final stream = Stream.value(utf8.encode(jsonStr));
    await _getClient().putObject(_config.bucket, key, stream, jsonStr.length);
  }

  Future<void> _uploadImageIfNeeded(Meme meme) async {
    final objectKey = 'memes/${meme.fileHash}${_ext(meme.filePath)}';
    try {
      await _getClient().statObject(_config.bucket, objectKey);
      // 已存在，跳过
    } on MinioException {
      // 不存在，上传
      final file = await _storage.getImage(meme.filePath);
      await _getClient().fPutObject(_config.bucket, objectKey, file.absolute.path);
    }
  }

  String _ext(String path) => path.contains('.') ? '.${path.split('.').last}' : '';
```

- [ ] **Step 5: 注入更新**

```dart
// lib/features/gallery/gallery_provider.dart
final s3SyncServiceProvider = Provider<S3SyncService>((ref) {
  final service = S3SyncService(
    memeRepo: ref.read(memeRepositoryProvider),
    albumRepo: ref.read(albumRepositoryProvider),
    storage: ref.read(fileStorageServiceProvider),
    syncStateDao: ref.read(databaseProvider).syncStateDao,
    serializer: S3SyncSerializer(
      memeRepo: ref.read(memeRepositoryProvider),
      albumRepo: ref.read(albumRepositoryProvider),
    ),
  );
  service.updateConfig(ref.read(s3ConfigProvider).valueOrNull ?? const S3Config());
  return service;
});
```

- [ ] **Step 6: 验证编译**

Run: `dart analyze lib/services/s3_sync_service.dart`
Expected: 无错误

- [ ] **Step 7: Commit**

```bash
git add lib/services/s3_sync_service.dart lib/features/gallery/gallery_provider.dart
git commit -m "feat: rewrite S3SyncService with full upload + connection test"
```

---

### Task 2.2: 全量下载 + 增量同步

> 实现 `downloadAll()`（全量恢复）和 `_runIncrementalSync()`（双向增量）。增量同步依赖 `updatedAt` 对比和 `deleted_ids.json`。

**Files:**
- Modify: `lib/services/s3_sync_service.dart`

- [ ] **Step 1: 实现 downloadAll()**

```dart
  /// 全量下载：拉取 snapshot → 清空本地 → 批量导入 → 按需拉图片
  Stream<SyncProgress> downloadAll() async* {
    if (!isConfigured) { /* yield error */ return; }
    _cancelled = false;

    // 1. 拉取最新 snapshot
    final snapshotJson = await _getJson('snapshot-v1.json');
    if (snapshotJson == null) {
      yield SyncProgress(status: SyncStatus.error, errorMessage: 'S3 上没有找到备份数据');
      return;
    }

    final data = FullSyncData.fromJson(snapshotJson as Map<String, dynamic>);
    final totalSteps = data.memes.length + 1; // 导入 + 下载图片

    // 2. 导入元数据（事务中清空 + 批量写）
    await _serializer.importFull(data);
    yield SyncProgress(status: SyncStatus.downloading, completed: 1, total: totalSteps);

    // 3. 按需下载图片
    var completed = 1;
    for (final memeData in data.memes) {
      if (_cancelled) return;
      try {
        await _downloadImageIfNeeded(memeData.meme);
      } catch (_) { /* 单张失败跳过 */ }
      completed++;
      yield SyncProgress(status: SyncStatus.downloading, completed: completed, total: totalSteps);
    }

    // 4. 更新同步状态
    await _syncStateDao.setLastSyncAt(DateTime.now().millisecondsSinceEpoch);
    yield SyncProgress(status: SyncStatus.idle, completed: completed, total: totalSteps);
  }
```

- [ ] **Step 2: 实现增量同步核心逻辑**

```dart
  /// 增量同步：上传本地变更 + 拉取 S3 变更
  Stream<SyncProgress> incremental() async* {
    if (!isConfigured) { /* yield error */ return; }
    _cancelled = false;

    final lastSyncAt = await _syncStateDao.getLastSyncAt();
    final now = DateTime.now().millisecondsSinceEpoch;

    // Phase 1: 上传本地变更
    // ... 查询 updatedAt > lastSyncAt 的 memes/albums，上传图片 + JSON
    // ... 同时构建 deleted_ids.json（如果有本地删除）

    // Phase 2: 拉取 S3 变更
    // ... 拉取 S3 的 deleted_ids.json，本地执行删除
    // ... 从 data/memes.json 筛选 updatedAt > lastSyncAt 的条目

    // Phase 3: 更新 last_sync_at
    await _syncStateDao.setLastSyncAt(now);
  }
```

- [ ] **Step 3: 实现周期性定时同步**

```dart
  Timer? _periodicTimer;

  void startPeriodicSync(Duration interval) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      if (_syncInProgress) return;
      final lastSyncAt = await _syncStateDao.getLastSyncAt();
      if (lastSyncAt == null) return; // 从未同步过，不做自动
      final hasChanges = await _memeRepo.hasChangesSince(lastSyncAt);
      if (!hasChanges) return;
      await for (final _ in incremental()) { /* 静默执行 */ }
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  bool get _syncInProgress => false; // 可由 streaming 状态追踪
```

- [ ] **Step 4: 验证编译**

Run: `dart analyze lib/services/s3_sync_service.dart`
Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git add lib/services/s3_sync_service.dart
git commit -m "feat: add download and incremental sync to S3SyncService"
```

---

## Chunk 3: UI 层

### Task 3.1: 创建独立同步页面

> 将 S3 同步从设置页的 Card 升级为独立路由页面，包含连接测试、上传/下载按钮、进度条、统计信息。

**Files:**
- Create: `lib/features/settings/s3_sync_screen.dart`
- Modify: `lib/features/settings/settings_screen.dart` (入口改为跳转)
- Modify: `lib/router.dart` (注册路由)

- [ ] **Step 1: 创建 s3_sync_screen.dart 骨架**

包含：
- 配置摘要 + 连接测试按钮
- 全量上传/下载/增量同步 三个按钮
- 进度条（LinearProgressIndicator + 文字）
- 统计区域（空间用量、文件数、上次同步时间）
- 清空 S3 数据按钮

- [ ] **Step 2: 在 router.dart 注册路由**

```dart
// lib/router.dart
// 新增 named route
GoRoute(
  path: '/settings/s3-sync',
  name: 's3-sync',
  builder: (context, state) => const S3SyncScreen(),
),
```

- [ ] **Step 3: 修改 settings_screen.dart 入口**

将 `_S3ConfigCard` 的 `current` 替换为跳转到 S3 同步页，保留配置摘要。

- [ ] **Step 4: 验证编译**

Run: `dart analyze lib/features/settings/`
Expected: 无错误

- [ ] **Step 5: Commit**

```bash
git add lib/features/settings/s3_sync_screen.dart lib/features/settings/settings_screen.dart lib/router.dart
git commit -m "feat: add S3 sync screen with progress UI"
```

---

### Task 3.2: 定时同步设置 UI

> 在同步页面添加定时同步开关 + 间隔选择器。

**Files:**
- Modify: `lib/features/settings/s3_sync_screen.dart`

- [ ] **Step 1: 添加定时同步控制组件**

```dart
Card(
  child: Column(children: [
    SwitchListTile(
      title: Text('定时自动同步'),
      subtitle: Text(autoSyncEnabled ? '每 ${intervalLabel} 同步一次' : '仅手动同步'),
      value: autoSyncEnabled,
      onChanged: (v) {
        ref.read(autoSyncProvider.notifier).setEnabled(v);
        if (v) service.startPeriodicSync(selectedInterval);
        else service.stopPeriodicSync();
      },
    ),
    if (autoSyncEnabled)
      ListTile(
        title: Text('同步间隔'),
        trailing: DropdownButton<Duration>(
          value: selectedInterval,
          items: [
            DropdownMenuItem(value: Duration(minutes: 5), child: Text('5 分钟')),
            DropdownMenuItem(value: Duration(minutes: 15), child: Text('15 分钟')),
            DropdownMenuItem(value: Duration(minutes: 30), child: Text('30 分钟')),
            DropdownMenuItem(value: Duration(hours: 1), child: Text('1 小时')),
            DropdownMenuItem(value: Duration(hours: 6), child: Text('6 小时')),
            DropdownMenuItem(value: Duration(days: 1), child: Text('1 天')),
          ],
          onChanged: (v) { /* 更新间隔 */ },
        ),
      ),
  ]),
)
```

- [ ] **Step 2: 创建 autoSyncProvider**

在 `gallery_provider.dart` 中新增 `autoSyncEnabledProvider` 和 `autoSyncIntervalProvider`，持久化到 SharedPreferences。

- [ ] **Step 3: 验证编译**

Run: `dart analyze lib/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/features/settings/s3_sync_screen.dart lib/features/gallery/gallery_provider.dart
git commit -m "feat: add periodic sync settings UI"
```

---

## Chunk 4: 管理功能

### Task 4.1: S3 存储统计

> 实现 `getStorageStats()`，遍历 S3 bucket 统计对象数量和总大小。

**Files:**
- Modify: `lib/services/s3_sync_service.dart`
- Modify: `lib/features/settings/s3_sync_screen.dart`

- [ ] **Step 1: 在 S3SyncService 中实现 getStorageStats()**

```dart
  Future<SyncStats> getStorageStats() async {
    int totalBytes = 0;
    int objectCount = 0;
    final objects = _getClient().listObjects(_config.bucket, recursive: true);
    await for (final obj in objects) {
      totalBytes += obj.size ?? 0;
      objectCount++;
    }
    return SyncStats(totalBytes: totalBytes, objectCount: objectCount);
  }
```

- [ ] **Step 2: 在页面中展示**

```dart
  // 使用 FutureBuilder 或 Riverpod 的 FutureProvider 调用 getStorageStats()
  // 显示: 已用空间 45.2 MB · 127 个文件
```

- [ ] **Step 3: 验证编译**

Run: `dart analyze lib/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/services/s3_sync_service.dart lib/features/settings/s3_sync_screen.dart
git commit -m "feat: add S3 storage statistics"
```

---

### Task 4.2: 清空 S3 数据 + 密码确认

> 实现 `clearAllData(password:)`，设置密码使用 flutter_secure_storage。

**Files:**
- Modify: `lib/services/s3_sync_service.dart`
- Modify: `lib/features/settings/s3_sync_screen.dart`

- [ ] **Step 1: 实现清空逻辑**

```dart
  Future<void> clearAllData({required String password}) async {
    final storage = const FlutterSecureStorage();
    final storedPw = await storage.read(key: 's3_clear_password');
    if (storedPw == null || storedPw != password) {
      throw SyncException('密码错误');
    }

    // 删除所有 object
    final client = _getClient();
    final objects = await client.listObjects(_config.bucket, recursive: true).toList();
    for (var i = 0; i < objects.length; i += 1000) {
      final batch = objects.skip(i).take(1000).map((o) => o.key!).toList();
      await client.removeObjects(_config.bucket, batch);
    }

    // 重置同步状态
    await _syncStateDao.reset();
  }

  Future<void> setClearPassword(String password) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 's3_clear_password', value: password);
  }
```

- [ ] **Step 2: 密码设置 + 清空确认 UI**

```dart
  // 设置密码: TextField + 确认密码
  // 清空流程: 警告弹窗 → 输入密码 → 错误重试 → 成功通知
```

- [ ] **Step 3: 验证编译**

Run: `dart analyze lib/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/services/s3_sync_service.dart lib/features/settings/s3_sync_screen.dart
git commit -m "feat: add S3 clear data with password confirmation"
```

---

### Task 4.3: MemeRepository 补充 hasChangesSince

> 增量同步需要查询 `updatedAt > timestamp` 的数据，当前 MemeRepository 没有这个方法。

**Files:**
- Modify: `lib/core/repositories/meme_repository.dart`
- Modify: `lib/core/database/daos/meme_dao.dart`

- [ ] **Step 1: MemeDao 添加查询**

```dart
// lib/core/database/daos/meme_dao.dart
Future<bool> hasChangesSince(int timestamp) async {
  final count = await (customSelect(
    'SELECT COUNT(*) as c FROM memes_table WHERE updated_at > ?',
    variables: [Variable.withInt(timestamp)],
  ).getSingle());
  return (count.data['c'] as int) > 0;
}

Future<List<Meme>> getUpdatedSince(int timestamp) async {
  return (select(memesTable)..where((t) => t.updatedAt.isBiggerThanValue(timestamp))).get();
}
```

- [ ] **Step 2: MemeRepository 暴露**

```dart
Future<bool> hasChangesSince(int timestamp) => _memeDao.hasChangesSince(timestamp);
```

- [ ] **Step 3: 验证编译**

Run: `dart analyze lib/core/`
Expected: 无错误

- [ ] **Step 4: Commit**

```bash
git add lib/core/repositories/meme_repository.dart lib/core/database/daos/meme_dao.dart
git commit -m "feat: add hasChangesSince and getUpdatedSince to MemeDao"
```

---

## 执行顺序

```
Chunk 1 (基础设施)
├── Task 1.1 SyncStateDao
├── Task 1.2 S3SyncSerializer
└── Task 1.3 S3Config 安全存储

Chunk 2 (核心同步逻辑)
├── Task 2.1 连通性测试 + 全量上传
└── Task 2.2 全量下载 + 增量同步

Chunk 3 (UI 层)
├── Task 3.1 独立同步页面
└── Task 3.2 定时同步设置

Chunk 4 (管理功能)
├── Task 4.1 存储统计
├── Task 4.2 清空 + 密码
└── Task 4.3 MemeDao 补充
```

依赖关系：
- Chunk 1 → Chunk 2 → Chunk 3 (串行)
- Task 4.3 可随时插入（无依赖）
- Task 4.1 / 4.2 依赖 Chunk 2
- Chunk 4 完成后 ⇔ Chunk 3 可合并

---

## 验证清单

- [ ] `dart analyze` 全线无错误
- [ ] `flutter build apk --release` 构建通过
- [ ] 配置 S3 后 `testConnection()` 返回正确结果
- [ ] 全量上传后 S3 bucket 中出现 memes/data/snapshot 目录
- [ ] 全量下载后本地数据与上传前一致
- [ ] 增量同步只传输变更数据
- [ ] 清空 S3 数据后 bucket 为空
- [ ] SharedPreferences 中不再存储明文 secretKey
- [ ] 定时同步在指定间隔执行
