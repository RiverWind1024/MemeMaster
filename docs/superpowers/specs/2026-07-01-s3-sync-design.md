# S3 云同步设计

> 2026-07-01 | 功能设计

## 1. 概述

MemeHelper 的现有 S3 同步只做了"上传图片文件"一件事。本文档设计完整的双向同步系统，覆盖数据完整性、增量同步、安全擦除等需求。

### 目标需求清单

| # | 需求 | 优先级 |
|---|------|--------|
| 0 | S3 配置 + 连通性测试 | P0 |
| 1 | 上传 meme 图片、标签、颜色、描述、相册 | P0 |
| 2 | 从 S3 全量/增量同步恢复 | P0 |
| 3 | 清空 S3 数据（密码确认） | P1 |
| 4 | S3 存储空间统计 | P1 |
| 5 | secretKey 安全存储 | P1 |

---

## 2. 数据模型

### 2.1 S3 Bucket 目录结构

```
{bucket}/
├── memes/
│   └── {fileHash}.{ext}              ← 图片文件（去重，hash 命名）
├── data/
│   ├── memes.json                     ← 所有 meme 元数据 + 标签 + 颜色
│   ├── albums.json                    ← 所有相册定义
│   └── meme_albums.json               ← meme ↔ 相册关联
├── snapshot-v{version}.json           ← 全量快照（meme+tag+color+album 合体）
└── .sync                              ← sync marker（存最新版本号/时间戳）
```

**设计理由：**

- 图片用 `fileHash` 命名天然去重，多个 meme 共享同一张图片不上传两次
- 元数据与图片分离，下载时先读 JSON 再按需拉图片，避免无效传输
- 全量快照用于新设备一次性恢复，增量基于 `.sync` 的时间戳做 diff

### 2.2 序列化格式

**memes.json** — 每条 Meme 的完整信息：

```json
[
  {
    "id": "uuid",
    "filename": "funny_cat.jpg",
    "fileHash": "abc123...",
    "fileSize": 102400,
    "mimeType": "image/jpeg",
    "width": 1920,
    "height": 1080,
    "description": "一只搞笑的猫",
    "analysisStatus": "done",
    "createdAt": 1719000000000,
    "updatedAt": 1719086400000,
    "tags": [
      { "source": "ocr", "content": "猫", "confidence": 0.95 },
      { "source": "manual", "content": "搞笑", "confidence": 1.0 }
    ],
    "colors": [
      { "hexColor": "#FF5733", "labL": 53.2, "labA": 40.3, "labB": 50.1, "ratio": 0.35 }
    ]
  }
]
```

**albums.json：**

```json
[
  { "id": "uuid", "name": "搞笑合集", "icon": "emoji_objects", "sortOrder": 1, "createdAt": 1719000000000 }
]
```

**meme_albums.json：**

```json
[
  { "memeId": "uuid", "albumId": "uuid", "addedAt": 1719000000000 }
]
```

### 2.3 同步状态追踪（`sync_state_table`）

复用已存在的 `SyncStateTable`，存两级 key：

| id | value | updatedAt | 说明 |
|----|-------|-----------|------|
| `last_sync_at` | `1719086400000` | — | 上次同步时间戳（毫秒） |
| `last_snapshot_version` | `3` | — | 上次全量快照版本号 |
| `last_pull_at` | `1719086400000` | — | 上次拉取时间戳 |

---

## 3. 架构

### 3.1 新增/修改文件

```
lib/
├── services/
│   ├── s3_config.dart                  ← 增强：pathStyle、connectTimeout
│   ├── s3_sync_service.dart            ← 重写：双向同步主逻辑
│   ├── s3_sync_serializer.dart         ← 新增：数据 ↔ JSON 序列化
│   └── s3_sync_state.dart              ← 新增：SyncStateTable DAO + 状态管理
├── core/
│   └── database/
│       └── tables/
│           └── sync_state_table.dart    ← 已有，无需改
├── features/
│   └── settings/
│       └── s3_sync_screen.dart          ← 新增：独立同步页面（取代 Card）
```

### 3.2 组件依赖

```
MemesRepository ──┐
TagDao ───────────┤
ColorDao ─────────┤── S3SyncSerializer ──→ S3SyncService ──→ Minio Client
AlbumDao ─────────┘                          │
                                        SyncStateDao
                                            (读写 last_sync_at)
```

### 3.3 S3SyncService 接口设计

```dart
class S3SyncService {
  // 配置
  void updateConfig(S3Config config);
  bool get isConfigured;
  Future<bool> testConnection();              // ← 新增: 连通性测试

  // 上传
  Stream<SyncProgress> uploadAll();           // ← 重写: 上传图片 + 元数据
  Stream<SyncProgress> uploadIncremental();   // ← 新增: 增量上传(基于 updatedAt)

  // 下载
  Stream<SyncProgress> downloadAll();         // ← 新增: 全量恢复
  Stream<SyncProgress> downloadIncremental(); // ← 新增: 增量拉取

  // 管理
  Future<SyncStats> getStorageStats();        // ← 新增: S3 空间统计
  Future<void> clearAllData({required String password}); // ← 新增: 清空

  // 取消（所有 Stream 均可通过 cancel 取消）
  void cancel();
}
```

---

## 4. 同步策略

### 4.1 触发模式

两种模式并行：

#### 4.1.1 手动同步（强制可用）

用户通过 UI 按钮触发：

| 操作 | 说明 |
|------|------|
| 全量上传 | 覆盖 S3 上的所有数据 |
| 全量下载 | 覆盖本地所有数据（从 S3 恢复） |
| 增量同步 | 自动检测双向变化，上传本地新数据 + 拉取 S3 新数据 |

#### 4.1.2 定时自动同步（默认关闭，用户可选开启）

当 App 在前台运行时，定时检查并增量同步。

| 选项 | 默认值 | 可选值 |
|------|--------|--------|
| 开启/关闭 | 关闭 | — |
| 间隔 | 15 分钟 | 5 / 15 / 30 分钟 / 1 小时 / 6 小时 / 1 天 |
| WiFi 仅同步 | 是 | 是/否 |

**实现方式：**

```dart
class S3SyncService {
  Timer? _periodicTimer;

  void startPeriodicSync(Duration interval) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(interval, (_) async {
      if (!await _isWifi()) return;  // 非 WiFi 跳过
      if (!await _hasLocalChanges()) return;  // 无变化跳过
      await _runIncrementalSync();
    });
  }

  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  Future<bool> _hasLocalChanges() async {
    final lastSync = await _syncStateDao.getLastSyncAt();
    return _memeRepo.hasChangesSince(lastSync);
  }
}
```

App 进入后台时自动暂停定时器，回到前台时恢复（监听 `AppLifecycleState`）。
非 WiFi 网络下定时同步跳过，不做任何提示。
没有"导入后自动触发"机制——只靠定时轮询 + 手动触发。

### 4.2 同步方向策略

| 场景 | 方向 | 说明 |
|------|------|------|
| 首次使用（新设备） | 全量下载 | 从 S3 恢复完整数据 |
| 日常使用 | 双向增量 | 上传本地新建/修改，下载 S3 端变更 |
| 迁移/换机 | 全量上传 → 新设备全量下载 | 先备份，再恢复 |

### 4.3 网络约束

| 条件 | 行为 |
|------|------|
| 无网络 | 所有同步操作静默失败，不弹错误提示，仅在日志记录 |
| 移动数据 | 自动同步跳过，手动同步允许（用户明确触发的） |
| WiFi | 正常执行（自动 + 手动） |

### 4.4 竞争避免

- 上传和下载不能同时执行（防止循环同步：A 上传 → B 下载 → 触发 B 上传 → A 下载）
- 同一时间只有一个同步任务在运行
- 如果同步进行中用户再次触发，提示"同步进行中"
- `deleted_ids.json` 在拉取后需在 S3 上删除或标记已消费，避免重复拉取

### 4.5 冲突策略

采用 **last-write-wins**（简单可靠）：

- 以 `updatedAt` 为准，较新的覆盖较旧的
- 如果时间戳相同，以 S3 端为准（因为"云"被视为 source of truth）
- 不处理复杂的合并（如两人分别添加不同标签到同一 meme），因为 MemeHelper 目前是单用户应用

### 4.1 连通性测试

```dart
Future<bool> testConnection() async {
  try {
    // 1. 尝试 listBuckets（最简单、权限要求最低的 S3 操作）
    await client.listBuckets();
    // 2. 尝试 headBucket（验证 bucket 是否存在、是否有权限访问）
    await client.headBucket(config.bucket);
    return true;
  } on MinioException catch (e) {
    _log.error('S3 连接测试失败', e);
    return false;
  }
}
```

权限需求：用户必须给 AccessKey 至少 `s3:ListAllMyBuckets` + `s3:HeadBucket` + `s3:PutObject` + `s3:GetObject` + `s3:ListBucket` + `s3:DeleteObject`。

### 4.2 全量上传

1. 序列化所有数据为 `memes.json`、`albums.json`、`meme_albums.json`
2. 上传到 `data/` 目录
3. 逐张上传图片到 `memes/{hash}.ext`（跳过已存在的 object）
4. 写入 `.sync` marker（记录时间戳）
5. 写入全量快照 `snapshot-v{version}.json`

**进度计算：**

```
total = memes.length (images) + 3 (JSON files) + 1 (snapshot)
```

### 4.3 增量上传

依赖 `updatedAt` 字段。Meme 表、Album 表、关联表在每次变更时都会更新 `updatedAt`。

1. 从 `SyncStateTable` 读取 `last_sync_at`
2. 查询 `updatedAt > last_sync_at` 的 meme + album + 关联
3. 只上传变化部分
4. 更新 `last_sync_at`

**新增数据会触发：**
- 新 meme 图片上传到 `memes/{hash}.ext`
- meme JSON 增量追加到 `data/memes.json`
- 相册变更写入 `data/albums.json`

**删除数据处理：**
meme 被删后，图片文件在 S3 上仍存在（因为其他 meme 可能引用同一 hash）。
但 `memes.json` 需要标记删除（软删：添加 `"deleted": true` 字段，或在增量同步时以单独的 `deleted_ids.json` 记录删除列表）。

设计采用 `deleted_ids.json`：

```json
{
  "memeIds": ["uuid1", "uuid2"],
  "albumIds": [],
  "updatedAt": 1719086400000
}
```

增量同步时，客户端先拉取 `deleted_ids.json`，本地执行软删/硬删。

### 4.4 全量下载

1. 从 S3 拉取 `snapshot-v{version}.json`
2. 清空本地 meme + tag + color + album + meme_album 表
3. 批量写入
4. 按需下载图片（下载前检查 `fileHash` 是否已在本地）
5. 更新 `last_sync_at`

### 4.5 增量下载

1. 拉取 `.sync` 获取 S3 端最新时间戳
2. 本地 `last_pull_at` 对比：
   - 如果差距超过阈值（如 7 天），自动建议全量
   - 否则增量
3. 拉取 `deleted_ids.json`，本地删除
4. 从 `data/memes.json` 中筛选 `updatedAt > last_pull_at` 的条目
5. 更新本地数据库
6. 按需下载新图片
7. 更新 `last_pull_at`

### 4.6 冲突策略

采用 **last-write-wins**（简单可靠）：

- 以 `updatedAt` 为准，较新的覆盖较旧的
- 如果时间戳相同，以 S3 端为准（因为"云"被视为 source of truth）
- 不处理复杂的合并（如两人分别添加不同标签到同一 meme），因为 MemeHelper 目前是单用户应用

---

## 5. 清空 S3 数据

### 5.1 用户流程

1. 用户在同步页点击「清空 S3 数据」
2. 弹出警告对话框："此操作将从 S3 删除所有 meme 数据，此操作不可撤销！"
3. 要求输入密码确认（密码 = 应用退出密码，或单独设置 S3 清空密码）
4. 输入正确后，执行清空：
   - `listObjects(bucket)` 遍历所有 object
   - 分批删除（每次最多 1000 个，因 AWS S3 API 限制）
   - Stream 返回进度
5. 完成后重置本地 `SyncStateTable`

### 5.2 密码存储

- 使用 `flutter_secure_storage`（已引入）存储 S3 清空密码
- 初始设置：在"设置"中可设置/修改 S3 清空密码
- 如果未设密码，清空操作直接拒绝，提示"请先设置 S3 清空密码"

### 5.3 技术实现

```dart
Future<void> clearAllData({required String password}) async {
  // 验证密码
  final stored = await _secureStorage.read(key: 's3_clear_password');
  if (stored == null || stored != password) {
    throw SyncException('密码错误');
  }

  // 批量删除（AWS S3 单次最多删 1000 个 object）
  final client = _getClient();
  final objects = await client.listObjects(config.bucket);
  for (var i = 0; i < objects.length; i += 1000) {
    final batch = objects.skip(i).take(1000).toList();
    await client.removeObjects(config.bucket, batch.map((o) => o.key!).toList());
  }

  // 重置本地同步状态
  await _syncStateDao.reset();
}
```

---

## 6. S3 存储空间统计

### 6.1 方案

```dart
Future<SyncStats> getStorageStats() async {
  final client = _getClient();
  int totalSize = 0;
  int objectCount = 0;

  final objects = client.listObjects(config.bucket, recursive: true);
  await for (final obj in objects) {
    totalSize += obj.size ?? 0;
    objectCount++;
  }

  return SyncStats(
    totalBytes: totalSize,
    objectCount: objectCount,
    lastUpdated: DateTime.now(),
  );
}
```

`listObjects` 返回所有 object 的元信息（包括 size），不需要逐个下载。开销与 object 数量成正比，10000 个 object 大约 1-3 秒。

### 6.2 展示

在同步页面显示：

```
S3 存储空间: 45.2 MB / 共 127 个文件
最后更新: 1 分钟前
```

---

## 7. 安全性改进

### 7.1 密钥存储（P1）

当前：`SharedPreferences` 明文存储。

改进：使用 `flutter_secure_storage`（已引入项目，只是未在 S3 配置中使用）加密存储 `accessKey` 和 `secretKey`。

```dart
class S3ConfigNotifier extends Notifier<S3Config> {
  @override
  S3Config build() async {
    final storage = FlutterSecureStorage();
    return S3Config(
      endpoint: await storage.read(key: 's3_endpoint') ?? '',
      bucket: await storage.read(key: 's3_bucket') ?? '',
      accessKey: await storage.read(key: 's3_access_key') ?? '',
      secretKey: await storage.read(key: 's3_secret_key') ?? '',
      // ...
    );
  }
}
```

**注意**：`Notifier.build()` 当前是同步的。需要改为 `AsyncNotifier` 以支持异步读取。

### 7.2 传输加密

配置 `useSSL: true`（已默认开启）强制 HTTPS。对于自建 MinIO 服务器，确保服务端配置了 TLS。

---

## 8. UI 设计

### 8.1 独立同步页面（`s3_sync_screen.dart`）

取代当前 Settings 中的 Card，改为独立的 route（可在设置中点击「S3 云同步」进入）。

布局：

```
┌─────────────────────────────┐
│ ← S3 云同步                │
├─────────────────────────────┤
│                             │
│  📡 连接状态: 已连接 ✔      │
│  [测试连接]                 │
│                             │
│  ┌─── 配置 ────────────┐   │
│  │ Endpoint: xxx        │   │
│  │ Bucket: xxx          │   │
│  │ Region: xxx          │   │
│  │ Access Key: ***      │   │
│  │ Secret Key: ***      │   │
│  └──────────────────────┘   │
│                             │
│  [⬆ 全量上传] [⬇ 全量下载]  │
│  [↕ 增量同步]               │
│                             │
│  进度: ████████░░ 80%      │
│  状态: 正在上传 (15/20)...  │
│                             │
│  ──── 统计 ────             │
│  已用空间: 45.2 MB         │
│  文件数量: 127              │
│  上次同步: 1 小时前         │
│                             │
│  [🗑 清空 S3 数据]          │
│                             │
└─────────────────────────────┘
```

### 8.2 关键交互

| 操作 | 行为 |
|------|------|
| 点「测试连接」 | 显示 loading → ✅ 已连接 / ❌ 失败: 错误信息 |
| 点「全量上传」 | 确认弹窗 → 开始 Stream 上传 → 进度条更新 → 完成通知 |
| 点「全量下载」 | 警告"将覆盖本地数据" → 确认 → 开始 Stream 下载 |
| 点「增量同步」 | 自动判断方向 → 上传变化 → 拉取变化 → SnackBar 结果 |
| 点「清空 S3」 | 警告弹窗 → 输入密码 → 错误则重试 → 确认后清空 |

---

## 9. 错误处理与恢复

| 场景 | 处理 |
|------|------|
| 网络中断 | Stream 抛出异常 → `onError` 回调显示 SnackBar → 不自动重试 |
| 配置错误（bucket 不存在） | `testConnection()` 即可暴露 |
| 部分上传失败 | 跳过失败项继续（不终止整个流程） |
| 下载时 JSON 损坏 | 回退到上一个版本的全量快照 |
| S3 限流（429） | 自动等待 1-3 秒后重试（指数退避） |
| 磁盘空间不足 | 下载前检查剩余空间，不够则报错 |

---

## 10. 实施计划

### Phase 1 (P0) — 核心同步

| # | 任务 | 文件 |
|---|------|------|
| 1 | 编写 `S3SyncSerializer` | `s3_sync_serializer.dart` |
| 2 | 编写 `SyncStateDao` | `s3_sync_state.dart` |
| 3 | 重写 `S3SyncService.uploadAll()`（全量上传 + 元数据） | `s3_sync_service.dart` |
| 4 | 实现 `testConnection()` | 同上 |
| 5 | 编写独立同步页面 UI | `s3_sync_screen.dart` |
| 6 | 路由注册 + 设置入口 | `router.dart` + `settings_screen.dart` |

### Phase 2 (P0) — 增量同步与下载

| # | 任务 | 文件 |
|---|------|------|
| 7 | 实现 `uploadIncremental()` | `s3_sync_service.dart` |
| 8 | 实现 `downloadAll()` + `downloadIncremental()` | 同上 |
| 9 | 实现 `deleted_ids.json` 机制 | 同上 |
| 10 | 全量快照 `snapshot-v{version}.json` 读写 | 同上 |

### Phase 3 (P1) — 管理功能

| # | 任务 | 文件 |
|---|------|------|
| 11 | `getStorageStats()` | `s3_sync_service.dart` |
| 12 | `clearAllData()` + 密码确认 UI | 同上 + `s3_sync_screen.dart` |
| 13 | key 迁移到 `flutter_secure_storage` | `gallery_provider.dart` |

---

## 11. 未纳入设计的功能（YAGNI）

- **多用户/共享** — 当前是单用户应用，不考虑多人同时操作时的合并冲突
- **图片压缩** — 原图上传，不压缩（用户期望完整质量）
- **后台自动同步** — 只做手动触发，不做定时后台同步
- **文件版本历史** — 不保留旧版本
- **加密上传** — 如果将来需要，可以在序列化后加 AES 加密（对用户透明）
