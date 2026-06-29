# MemeHelper 同步与存储设计

> 所属项目: MemeHelper
> 文档编号: 05-sync-storage.md
> 涉及: 文件组织、S3 同步协议、冲突解决、安全

---

## 1. 本地存储结构

### 1.1 完整目录树

```
Android App 内部存储 (getApplicationDocumentsDirectory())
│
├── memes/                          # 所有 meme 图片
│   ├── 2026/                       # 按年归档
│   │   ├── 01/                     # 按月归档
│   │   │   ├── a1b2c3d4-....png    # UUID 命名
│   │   │   ├── e5f6g7h8-....jpg
│   │   │   └── ...
│   │   ├── 02/
│   │   └── ...
│   ├── 2027/
│   └── ...
│
├── models/                         # GGUF 模型文件
│   ├── moondream-2b-Q4_K_M.gguf
│   ├── all-MiniLM-L6-v2-Q4_K_M.gguf
│   └── .download/                  # 下载中的临时文件
│       └── moondream-2b-Q4_K_M.gguf.part
│
├── database/
│   └── meme_helper.db              # SQLite 数据库文件
│
├── cache/
│   ├── thumbnails/                 # 缩略图缓存
│   │   ├── 256x256/
│   │   │   ├── {meme_id}.jpg
│   │   │   └── ...
│   │   └── 512x512/
│   └── color_cache.json            # 颜色搜索结果缓存
│
├── temp/                           # 临时文件
│   └── zip_extract_XXXXX/          # ZIP 解压临时目录
│
└── exports/                        # 同步导出缓存
    └── sync_manifest_XXXXX.json
```

### 1.2 文件命名规则

| 类型 | 命名规则 | 示例 |
|------|---------|------|
| Meme 图片 | `{uuid}.{ext}` | `a1b2c3d4-e5f6-7890-abcd-ef1234567890.png` |
| 缩略图 | `{meme_id}.jpg` | `a1b2c3d4-....jpg` |
| GGUF 模型 | `{model-name}.gguf` | `moondream-2b-Q4_K_M.gguf` |
| 临时文件 | 原描述 + `.part` | `moondream-2b-Q4_K_M.gguf.part` |

### 1.3 存储空间管理

```dart
class StorageManager {
  /// 获取各项占用（字节）
  Future<StorageInfo> getStorageInfo() async {
    final appDir = await getApplicationDocumentsDirectory();
    return StorageInfo(
      memesSize: await _getDirSize(Directory('${appDir.path}/memes')),
      modelsSize: await _getDirSize(Directory('${appDir.path}/models')),
      databaseSize: await File('${appDir.path}/database/meme_helper.db').length(),
      cacheSize: await _getDirSize(Directory('${appDir.path}/cache')),
    );
  }

  /// 导入前检查空间
  Future<bool> hasSpaceFor(int fileSizeBytes) async {
    final free = await _getFreeDiskSpace();     // 获取剩余空间
    final threshold = 500 * 1024 * 1024;        // 保留 500MB 余量
    return free - fileSizeBytes > threshold;
  }

  /// 清理缩略图缓存
  Future<void> clearThumbnailCache() async {
    final cacheDir = Directory('${appDir.path}/cache/thumbnails');
    if (await cacheDir.exists()) {
      await cacheDir.delete(recursive: true);
    }
  }
}
```

---

## 2. S3 同步协议

### 2.1 S3 Bucket 结构

```
s3://meme-helper-sync/                           # 根 Bucket
│
├── devices/
│   ├── {device_uuid_1}/                         # 每个设备一个目录
│   │   ├── manifest.json                       # 设备文件清单
│   │   ├── data/
│   │   │   ├── memes/
│   │   │   │   ├── a1b2c3d4-....png            # meme 图片
│   │   │   │   ├── e5f6g7h8-....jpg
│   │   │   │   └── ...
│   │   │   └── metadata.ndjson                 # 增量元数据 (NDJSON)
│   │   └── snapshots/
│   │       └── 2026-06-29T120000Z_full.json    # 全量快照（按时间戳）
│   │
│   └── {device_uuid_2}/
│       └── ...
│
└── .sync-lock                                   # (可选)同步锁防止冲突
```

### 2.2 Manifest 格式

```json
{
  "deviceId": "uuid-xxxx",
  "lastSyncAt": "2026-06-29T12:00:00Z",
  "files": [
    {
      "memeId": "a1b2c3d4-...",
      "filename": "funny-cat.jpg",
      "path": "memes/2026/06/a1b2c3d4-....jpg",
      "sha256": "abc123def456...",
      "fileSize": 255432,
      "updatedAt": "2026-06-29T10:30:00Z",
      "isDeleted": false
    }
  ],
  "totalMemeCount": 1234,
  "totalBytes": 524288000
}
```

### 2.3 增量元数据格式 (NDJSON)

每行一个 JSON 对象，记录单个 meme 的完整元数据（不含图片本身）：

```jsonl
{"memeId":"uuid-1","filename":"cat.jpg","folderId":"f-1","fileSize":255432,"sha256":"abc...","analysisStatus":"done","tags":[{"source":"ocr","content":"哈哈哈"}],"colors":[{"hex":"#FF0000","ratio":0.4,"labL":53.2,"labA":80.1,"labB":67.2}],"createdAt":1728000000000,"updatedAt":1728090000000}
{"memeId":"uuid-2","filename":"dog.jpg","folderId":null,"fileSize":102400,"sha256":"def...","analysisStatus":"pending","tags":[],"colors":[],"createdAt":1728000000000,"updatedAt":1728000000000}
```

### 2.4 同步流程实现

```dart
// lib/services/sync_service.dart
class SyncService {
  final S3Client _s3;
  final MemeDao _memeDao;
  final TagDao _tagDao;
  final ColorDao _colorDao;
  final FolderDao _folderDao;
  final SyncStateDao _syncStateDao;

  static const String bucketName = 'meme-helper-sync';

  Future<SyncResult> sync() async {
    final deviceId = await _getDeviceId();
    final lastSyncAt = await _syncStateDao.getLastSyncTime();

    try {
      // 步骤 1: 上传本地变更
      await _uploadChanges(deviceId, lastSyncAt);

      // 步骤 2: 下载远端变更
      await _downloadChanges(deviceId, lastSyncAt);

      // 步骤 3: 记录同步时间
      await _syncStateDao.setLastSyncTime(DateTime.now());

      return SyncResult(success: true);
    } on SyncException catch (e) {
      return SyncResult(success: false, error: e.message);
    }
  }
}
```

---

## 3. 增量上传

```dart
Future<void> _uploadChanges(String deviceId, DateTime? since) async {
  final prefix = 'devices/$deviceId/';

  // 1. 获取本地变更的 meme
  final changedMemes = await _memeDao.findChanged(since);
  final deletedIds = await _memeDao.findDeleted(since);

  // 2. 上传新增/修改的图片
  for (final meme in changedMemes) {
    final s3Path = '${prefix}data/memes/${meme.id}.${_extension(meme.mimeType)}';
    final file = File(meme.filePath);

    if (await file.exists()) {
      await _s3.putObject(
        bucketName,
        s3Path,
        file.readAsBytes(),
      );
    }
  }

  // 3. 上传增量元数据
  if (changedMemes.isNotEmpty || deletedIds.isNotEmpty) {
    final metadataLines = <String>[];
    for (final meme in changedMemes) {
      final tags = await _tagDao.getByMemeId(meme.id);
      final colors = await _colorDao.getByMemeId(meme.id);
      metadataLines.add(jsonEncode(_memeToSyncJson(meme, tags, colors)));
    }
    for (final id in deletedIds) {
      metadataLines.add(jsonEncode({'memeId': id, 'isDeleted': true}));
    }

    final ndjsonPath = '${prefix}data/metadata.ndjson';
    // 追加到远端 NDJSON 文件（或上传新文件）
    final existingBytes = await _s3.getObject(bucketName, ndjsonPath);
    final appended = utf8.decode(existingBytes ?? []) +
                      metadataLines.join('\n') + '\n';
    await _s3.putObject(bucketName, ndjsonPath, utf8.encode(appended));
  }

  // 4. 更新 Manifest
  final manifest = await _buildManifest(changedMemes, deletedIds);
  await _s3.putObject(
    bucketName,
    '${prefix}manifest.json',
    utf8.encode(jsonEncode(manifest)),
  );
}
```

---

## 4. 增量下载

```dart
Future<void> _downloadChanges(String deviceId, DateTime? since) async {
  final prefix = 'devices/$deviceId/';

  // 1. 获取远端 manifest
  final manifestBytes = await _s3.getObject(
    bucketName, '${prefix}manifest.json'
  );
  if (manifestBytes == null) return;  // 远端无数据

  final remoteManifest = jsonDecode(utf8.decode(manifestBytes));

  // 2. 对比本地和远端，找出差异
  final localHashes = await _memeDao.getAllHashes();
  final remoteFiles = (remoteManifest['files'] as List)
    .map((f) => RemoteFile.fromJson(f));
  final devicePrefix = 'devices/$deviceId/';

  // 需要下载的：远端有但本地没有 或 hash 不同
  final toDownload = remoteFiles
    .where((f) =>
      !f.isDeleted &&
      (!localHashes.containsKey(f.memeId) ||
       localHashes[f.memeId] != f.sha256))
    .toList();

  // 需要删除的：远端标记为删除 或 本地有但远端无
  final remoteIds = remoteFiles.map((f) => f.memeId).toSet();
  final remoteDeletedIds = remoteFiles
    .where((f) => f.isDeleted)
    .map((f) => f.memeId)
    .toSet();
  final localIds = await _memeDao.getAllIds();

  final toDelete = localIds.difference(remoteIds).union(remoteDeletedIds);

  // 3. 下载图片
  for (final file in toDownload) {
    final bytes = await _s3.getObject(bucketName, file.path);
    if (bytes != null) {
      await _saveDownloadedMeme(file, bytes);
    }
  }

  // 4. 处理删除
  for (final id in toDelete) {
    await _memeDao.softDelete(id);
  }

  // 5. 下载增量元数据并应用
  final metadataBytes = await _s3.getObject(
    bucketName, '${prefix}data/metadata.ndjson'
  );
  if (metadataBytes != null) {
    await _applyMetadata(utf8.decode(metadataBytes));
  }
}
```

---

## 5. 冲突解决

### 5.1 冲突矩阵

```
本地 \ 远端   | 创建      | 更新      | 删除      | 无变更
──────────────┼───────────┼───────────┼───────────┼───────────
创建          | 保留较新  | 保留较新  | 保留本地  | 上传本地
更新          | 保留远端  | 保留较新  | 保留远端  | 上传本地
删除          | 保留远端  | 保留远端  | 一致      | 上传删除
无变更        | 下载远端  | 下载远端  | 下载删除  | 无操作
```

### 5.2 冲突解决实现

```dart
ConflictAction resolveConflict(
  MemeLocal local,
  MemeRemote remote,
) {
  // 如果有一方标记为删除
  if (remote.isDeleted) {
    // 远端删除：如果本地有未同步更新则保留本地
    if (local.updatedAt.isAfter(remote.updatedAt) && !local.syncCompleted) {
      return ConflictAction.keepLocal;
    }
    return ConflictAction.applyRemoteDelete;
  }

  if (local.isDeleted) {
    if (remote.updatedAt.isAfter(local.deletedAt)) {
      return ConflictAction.applyRemote;
    }
    return ConflictAction.deleteLocal;
  }

  // 双方都有更新：保留更新较新的
  if (local.updatedAt.isAfter(remote.updatedAt)) {
    return ConflictAction.keepLocal;
  }
  return ConflictAction.applyRemote;
}
```

---

## 6. 安全

### 6.1 凭证存储

```dart
// 使用 flutter_secure_storage 加密存储 S3 凭证
final secureStorage = FlutterSecureStorage();

// 写入
await secureStorage.write(key: 's3_access_key', value: accessKey);
await secureStorage.write(key: 's3_secret_key', value: secretKey);
await secureStorage.write(key: 's3_endpoint', value: endpoint);
await secureStorage.write(key: 's3_bucket', value: bucket);
await secureStorage.write(key: 's3_region', value: region);

// 读取
final accessKey = await secureStorage.read(key: 's3_access_key');
final secretKey = await secureStorage.read(key: 's3_secret_key');
```

### 6.2 传输加密

S3 默认使用 HTTPS 传输加密。如需客户端加密：

```dart
// 上传前加密（AES-256-GCM）
Future<Uint8List> _encryptBeforeUpload(Uint8List data, Uint8List key) async {
  final cipher = AESCipher(key);
  final encrypted = await cipher.encrypt(data, AESMode.gcm);
  return encrypted.bytes;
}

// 下载后解密
Future<Uint8List> _decryptAfterDownload(Uint8List encrypted, Uint8List key) async {
  final cipher = AESCipher(key);
  final decrypted = await cipher.decrypt(encrypted, AESMode.gcm);
  return decrypted;
}
```

---

## 7. S3 客户端初始化

```dart
import 'package:minio/minio.dart';

Minio _createS3Client() {
  return Minio(
    endPoint: endpoint,          // s3.amazonaws.com 或 自建地址
    accessKey: accessKey,
    secretKey: secretKey,
    region: region,              // us-east-1 或 auto
    useSSL: true,
  );
}

// 支持的 S3 兼容服务:
// - AWS S3:        s3.amazonaws.com
// - Cloudflare R2: <account>.r2.cloudflarestorage.com
// - Backblaze B2:  s3.<region>.backblazeb2.com
// - MinIO:         <host>:9000 (自建)
// - AliCloud OSS:  oss-<region>.aliyuncs.com
```

---

## 8. 同步状态显示

```dart
@freezed
class SyncStatus with _$SyncStatus {
  const factory SyncStatus({
    required bool isConfigured,      // S3 是否已配置
    required bool isSyncing,         // 正在同步中
    required DateTime? lastSyncAt,   // 上次同步时间
    required int? pendingUpload,     // 待上传数量
    required int? pendingDownload,   // 待下载数量
    required String? lastError,      // 上次错误信息
  }) = _SyncStatus;
}
```

UI 层面在设置页显示同步状态卡片：

```
┌──────────────────────────────────┐
│  S3 同步                           │
│                                   │
│  ✓ 已配置                         │
│  上次同步: 10 分钟前                │
│  待上传: 3 个 | 待下载: 1 个       │
│                                   │
│  [立即同步]  [自动同步 ✓]          │
└──────────────────────────────────┘
```
