import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:minio/io.dart';
import 'package:minio/minio.dart';

import '../core/database/daos/sync_state_dao.dart';
import '../core/database/database.dart';
import '../core/repositories/album_repository.dart';
import '../core/repositories/meme_repository.dart';
import 'file_storage_service.dart';
import 'log_service.dart';
import 's3_config.dart';
import 's3_sync_serializer.dart';

/// S3 存储统计
class SyncStats {
  final int totalBytes;
  final int objectCount;

  const SyncStats({required this.totalBytes, required this.objectCount});
}

/// S3 同步服务
///
/// 实现与 S3 兼容存储的双向同步（图片 + 元数据）。
class S3SyncService {
  final MemeRepository _memeRepo;
  final AlbumRepository _albumRepo;
  final FileStorageService _storage;
  final SyncStateDao _syncStateDao;
  final S3SyncSerializer _serializer;
  final LogService? _log;
  S3Config _config = const S3Config();
  Minio? _client;
  bool _cancelled = false;
  bool _syncInProgress = false;
  Timer? _periodicTimer;

  S3SyncService({
    required MemeRepository memeRepo,
    required AlbumRepository albumRepo,
    required FileStorageService storage,
    required SyncStateDao syncStateDao,
    required S3SyncSerializer serializer,
    LogService? log,
  })  : _memeRepo = memeRepo,
        _albumRepo = albumRepo,
        _storage = storage,
        _syncStateDao = syncStateDao,
        _serializer = serializer,
        _log = log;

  S3Config get config => _config;

  void updateConfig(S3Config config) {
    _config = config;
    _client = null;
  }

  bool get isConfigured => _config.isValid;

  // ---- 客户端管理 ----

  Minio _getClient() {
    _client ??= Minio(
      endPoint: _config.endpoint,
      accessKey: _config.accessKey,
      secretKey: _config.secretKey,
      region: _config.region,
      useSSL: _config.useSsl,
      pathStyle: _config.pathStyle,
    );
    return _client!;
  }

  /// 确保 bucket 存在（不存在则创建）
  Future<void> _ensureBucket() async {
    final exists = await _getClient().bucketExists(_config.bucket);
    if (!exists) {
      await _getClient().makeBucket(_config.bucket, _config.region);
    }
  }

  // ---- 连通性测试 ----

  /// 测试 S3 连接是否正常
  Future<bool> testConnection() async {
    try {
      await _getClient().listBuckets();
      return true;
    } catch (e) {
      _log?.warning('S3 连接测试失败', e.toString());
      return false;
    }
  }

  // ---- 全量上传 ----

  /// 上传所有 meme 到 S3（图片 + 元数据 + 快照）
  Stream<S3SyncProgress> uploadAll() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }
    _cancelled = false;
    _syncInProgress = true;

    try {
      await _ensureBucket();

      final snapshot = await _serializer.exportFull(1);
      final totalSteps = snapshot.memes.length + 3;

      yield S3SyncProgress(
        status: S3SyncStatus.uploading,
        completed: 0,
        total: totalSteps,
      );

      // 上传元数据 JSON
      await _uploadJson('data/memes.json',
          snapshot.memes.map((m) => m.toJson()).toList());
      await _uploadJson(
          'data/albums.json',
          snapshot.albums
              .map((a) => {
                    'id': a.id,
                    'name': a.name,
                    'icon': a.icon,
                    'sortOrder': a.sortOrder,
                    'isDefault': a.isDefault,
                    'createdAt': a.createdAt,
                  })
              .toList());
      await _uploadJson('snapshot-v1.json', snapshot.toJson());

      var completed = 3;
      for (final memeData in snapshot.memes) {
        if (_cancelled) {
          yield S3SyncProgress(
            status: S3SyncStatus.idle,
            completed: completed,
            total: totalSteps,
            errorMessage: '已取消',
          );
          return;
        }

        try {
          await _uploadImageIfNeeded(memeData.meme);
        } catch (e) {
          yield S3SyncProgress(
            status: S3SyncStatus.error,
            completed: completed,
            total: totalSteps,
            errorMessage: '图片上传失败: ${memeData.meme.filename}: $e',
          );
          completed++;
          continue;
        }
        completed++;
        yield S3SyncProgress(
          status: S3SyncStatus.uploading,
          completed: completed,
          total: totalSteps,
        );
      }

      await _syncStateDao.setLastSyncAt(
          DateTime.now().millisecondsSinceEpoch);
      await _syncStateDao.setLastSnapshotVersion(1);

      yield S3SyncProgress(
        status: S3SyncStatus.idle,
        completed: completed,
        total: totalSteps,
      );
    } catch (e) {
      _log?.error('全量上传失败', e.toString());
      yield S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _uploadJson(String key, dynamic data) async {
    final jsonStr = jsonEncode(data);
    final stream = Stream.value(Uint8List.fromList(utf8.encode(jsonStr)));
    await _getClient().putObject(
      _config.bucket,
      key,
      stream,
      size: jsonStr.length,
    );
  }

  Future<void> _uploadImageIfNeeded(Meme meme) async {
    final objectKey = 'memes/${meme.fileHash}${_ext(meme.filePath)}';
    try {
      await _getClient().statObject(_config.bucket, objectKey);
      // 已存在则跳过
    } on MinioS3Error {
      final file = await _storage.getImage(meme.filePath);
      await _getClient().fPutObject(
        _config.bucket,
        objectKey,
        file.absolute.path,
      );
    }
  }

  Future<dynamic> _getJson(String key) async {
    try {
      final stream = await _getClient().getObject(_config.bucket, key);
      final bytes = await stream.first;
      return jsonDecode(utf8.decode(bytes));
    } on MinioS3Error {
      return null;
    }
  }

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    return dot >= 0 ? path.substring(dot) : '';
  }

  // ---- 取消 ----

  void cancel() {
    _cancelled = true;
  }

  // ---- 存储统计 ----

  /// 遍历 S3 bucket 统计存储用量。
  /// 未配置 S3 时抛出异常（调用方应只在已配置时调用）。
  Future<SyncStats> getStorageStats() async {
    if (!isConfigured) {
      throw StateError('S3 未配置');
    }
    int totalBytes = 0;
    int objectCount = 0;
    final results =
        _getClient().listObjects(_config.bucket, recursive: true);
    await for (final batch in results) {
      for (final obj in batch.objects) {
        totalBytes += obj.size ?? 0;
        objectCount++;
      }
    }
    return SyncStats(totalBytes: totalBytes, objectCount: objectCount);
  }

  // ---- 清空 S3 数据 ----

  /// 删除 S3 bucket 中所有对象并重置同步状态
  Future<void> clearAllData({required String password}) async {
    const storage = FlutterSecureStorage();
    final storedPw = await storage.read(key: 's3_clear_password');
    if (storedPw == null || storedPw != password) {
      throw ArgumentError('密码错误');
    }

    final client = _getClient();
    final allKeys = <String>[];
    final results =
        client.listObjects(_config.bucket, recursive: true);
    await for (final batch in results) {
      for (final obj in batch.objects) {
        if (obj.key != null) allKeys.add(obj.key!);
      }
    }
    for (var i = 0; i < allKeys.length; i += 1000) {
      final chunk = allKeys.skip(i).take(1000).toList();
      if (chunk.isNotEmpty) {
        await client.removeObjects(_config.bucket, chunk);
      }
    }

    await _syncStateDao.reset();
  }

  /// 设置清空操作的密码
  Future<void> setClearPassword(String password) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: 's3_clear_password', value: password);
  }

  // ---- 清空密码管理 ----

  /// 检查是否已设置清空密码
  Future<bool> hasClearPassword() async {
    const storage = FlutterSecureStorage();
    final pw = await storage.read(key: 's3_clear_password');
    return pw != null && pw.isNotEmpty;
  }

  // ---- 全量下载 ----

  /// 从 S3 全量下载并恢复数据
  Stream<S3SyncProgress> downloadAll() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }
    _cancelled = false;
    _syncInProgress = true;

    try {
      // 1. 拉取最新 snapshot
      final snapshotJson = await _getJson('snapshot-v1.json');
      if (snapshotJson == null) {
        yield const S3SyncProgress(
          status: S3SyncStatus.error,
          errorMessage: 'S3 上没有找到备份数据',
        );
        return;
      }

      final data = FullSyncData.fromJson(snapshotJson as Map<String, dynamic>);
      final totalSteps = data.memes.length + 1;

      // 2. 导入元数据（事务中清空 + 批量写）
      await _serializer.importFull(data);
      yield S3SyncProgress(
        status: S3SyncStatus.downloading,
        completed: 1,
        total: totalSteps,
      );

      // 3. 按需下载图片
      var completed = 1;
      for (final memeData in data.memes) {
        if (_cancelled) {
          yield S3SyncProgress(
            status: S3SyncStatus.idle,
            completed: completed,
            total: totalSteps,
            errorMessage: '已取消',
          );
          return;
        }
        try {
          await _downloadImageIfNeeded(memeData.meme);
        } catch (e) {
          _log?.warning('图片下载失败', '${memeData.meme.filename}: $e');
        }
        completed++;
        yield S3SyncProgress(
          status: S3SyncStatus.downloading,
          completed: completed,
          total: totalSteps,
        );
      }

      // 4. 更新同步状态
      await _syncStateDao.setLastSyncAt(
          DateTime.now().millisecondsSinceEpoch);
      await _syncStateDao.setLastSnapshotVersion(1);

      yield S3SyncProgress(
        status: S3SyncStatus.idle,
        completed: completed,
        total: totalSteps,
      );
    } catch (e) {
      _log?.error('全量下载失败', e.toString());
      yield S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: '下载失败: $e',
      );
    } finally {
      _syncInProgress = false;
    }
  }

  Future<void> _downloadImageIfNeeded(Meme meme) async {
    final objectKey = 'memes/${meme.fileHash}${_ext(meme.filePath)}';
    try {
      // 检查本地是否已存在
      final localFile = await _storage.getImage(meme.filePath);
      if (await localFile.exists()) return;

      // 从 S3 下载
      final stream = await _getClient().getObject(_config.bucket, objectKey);
      final dir = localFile.parent;
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      await stream.pipe(localFile.openWrite());
    } on MinioS3Error {
      // S3 上也没有，跳过
    }
  }

  // ---- 增量同步 ----

  /// 双向增量同步：上传本地变更 + 拉取 S3 变更
  Stream<S3SyncProgress> incremental() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }
    _cancelled = false;
    _syncInProgress = true;

    try {
      final lastSyncAt = await _syncStateDao.getLastSyncAt();
      final now = DateTime.now().millisecondsSinceEpoch;

      // Phase 1: 上传本地变更
      if (lastSyncAt != null) {
        final updatedMemes = await _memeRepo.getUpdatedSince(lastSyncAt);
        if (updatedMemes.isNotEmpty) {
          final totalSteps = updatedMemes.length + 2;
          yield S3SyncProgress(
            status: S3SyncStatus.uploading,
            completed: 0,
            total: totalSteps,
          );

          var completed = 0;
          for (final meme in updatedMemes) {
            if (_cancelled) {
              yield S3SyncProgress(
                status: S3SyncStatus.idle,
                errorMessage: '已取消',
              );
              return;
            }
            try {
              await _uploadImageIfNeeded(meme);
            } catch (e) {
              _log?.warning('增量上传图片失败', '$meme.filename: $e');
            }
            completed++;

            // 上传单条 meme 元数据
            try {
              final memeData = await _serializer.exportSingleMeme(meme.id);
              if (memeData != null) {
                final key = 'data/memes/${meme.id}.json';
                await _uploadJson(key, memeData.toJson());
              }
            } catch (e) {
              _log?.warning('增量上传元数据失败', '$meme.filename: $e');
            }

            yield S3SyncProgress(
              status: S3SyncStatus.uploading,
              completed: completed,
              total: totalSteps,
            );
          }
        }
      }

      // Phase 2: 从 S3 拉取更新
      // 当前简单策略：仅上传本地变更
      // 如果从未全量下载过则要求先全量下载
      if (lastSyncAt == null) {
        yield const S3SyncProgress(
          status: S3SyncStatus.idle,
          errorMessage: '请先执行全量下载',
        );
        return;
      }
      // TODO: 后续可扩展为基于 deleted_ids.json 的双向删除同步

      // Phase 3: 更新同步时间
      await _syncStateDao.setLastSyncAt(now);

      yield const S3SyncProgress(status: S3SyncStatus.idle);
    } catch (e) {
      _log?.error('增量同步失败', e.toString());
      yield S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: '增量同步失败: $e',
      );
    } finally {
      _syncInProgress = false;
    }
  }

  // ---- 定时同步 ----

  /// 启动定时同步
  void startPeriodicSync(Duration interval) {
    _periodicTimer?.cancel();
    _log?.info('S3Sync', '定时同步已启动, 间隔: $interval');
    _periodicTimer = Timer.periodic(interval, (_) async {
      if (_syncInProgress) return;
      final lastSyncAt = await _syncStateDao.getLastSyncAt();
      if (lastSyncAt == null) return; // 从未同步过，不做自动
      final hasChanges = await _memeRepo.hasChangesSince(lastSyncAt);
      if (!hasChanges) return;
      await for (final _ in incremental()) {
        // 静默执行，不暴露进度到 UI
      }
    });
  }

  /// 停止定时同步
  void stopPeriodicSync() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    _log?.info('S3Sync', '定时同步已停止');
  }
}
