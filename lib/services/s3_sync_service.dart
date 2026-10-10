import 'dart:async';
import 'dart:convert';

import 'package:minio/minio.dart';

import '../core/database/daos/sync_state_dao.dart';
import 'log_service.dart';
import 'object_store.dart';
import 's3_config.dart';
import 's3_manifest.dart';
import 's3_secret_store.dart';
import 's3_sync_engine.dart';

/// S3 存储统计
class SyncStats {
  final int totalBytes;
  final int objectCount;

  /// manifest 中被引用的图片哈希数量
  final int referencedImages;

  /// 未被 manifest 引用的图片（孤儿）数量
  final int orphanImages;

  /// 非 blob 的元数据对象数量
  final int metaFiles;

  const SyncStats({
    required this.totalBytes,
    required this.objectCount,
    required this.referencedImages,
    required this.orphanImages,
    required this.metaFiles,
  });
}

/// S3 同步服务
///
/// 实现与 S3 兼容存储的双向同步（图片 + 元数据），实际同步逻辑委托给
/// [SyncEngine]；本类只负责配置/客户端管理、连通性测试、统计与清空。
class S3SyncService {
  final ObjectStore _store;
  final SyncEngine _engine;
  final SyncStateDao _syncStateDao;
  final S3SecretStore _secretStore;
  final LogService? _log;
  S3Config _config = const S3Config();
  Minio? _client;
  bool _cancelled = false;

  /// 清空密码在 S3SecretStore 中的键名
  static const clearPasswordKey = 's3_clear_password';

  S3SyncService({
    required ObjectStore store,
    required SyncEngine engine,
    required SyncStateDao syncStateDao,
    required S3SecretStore secretStore,
    LogService? log,
  })  : _store = store,
        _engine = engine,
        _syncStateDao = syncStateDao,
        _secretStore = secretStore,
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

  // ---- 同步 ----

  /// 双向增量同步：委托 [SyncEngine.sync]（三阶段 LWW）。
  Stream<S3SyncProgress> incremental() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }
    _cancelled = false;
    yield const S3SyncProgress(
      status: S3SyncStatus.uploading,
      completed: 0,
      total: 1,
    );
    try {
      await _ensureBucket();
      if (_cancelled) {
        yield const S3SyncProgress(
          status: S3SyncStatus.idle,
          errorMessage: '已取消',
        );
        return;
      }
      final r = await _engine.sync();
      yield S3SyncProgress(
        status: S3SyncStatus.idle,
        completed: 1,
        total: 1,
        summary: '完成：推送 ${r.pushed} / 拉取 ${r.pulled} / 删除 ${r.deleted} / '
            '上传图片 ${r.imagesUploaded} / 下载图片 ${r.imagesDownloaded} / '
            '失败 ${r.failed}',
      );
    } catch (e) {
      _log?.error('S3 增量同步失败', e.toString());
      yield S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: '同步失败: $e',
      );
    }
  }

  /// 全量上传的别名。
  ///
  /// 引擎为双向 LWW 同步，无法只做单向推送，因此与 [incremental] 等价。
  Stream<S3SyncProgress> uploadAll() => incremental();

  /// 全量下载的别名。
  ///
  /// 引擎为双向 LWW 同步，无法只做单向拉取，因此与 [incremental] 等价。
  Stream<S3SyncProgress> downloadAll() => incremental();

  // ---- 取消 ----

  /// 请求取消。
  ///
  /// 注意：当前实现无法中断已经开始的 [SyncEngine.sync]；保留此方法以兼容 UI。
  void cancel() {
    _cancelled = true;
  }

  // ---- 存储统计 ----

  /// 遍历 S3 bucket 统计存储用量与图片分项。
  /// 未配置 S3 时抛出异常（调用方应只在已配置时调用）。
  Future<SyncStats> getStorageStats() async {
    if (!isConfigured) {
      throw StateError('S3 未配置');
    }
    int totalBytes = 0;
    int objectCount = 0;
    try {
      final withSizes = await _store.listWithSizes('');
      for (final size in withSizes.values) {
        totalBytes += size;
      }
      objectCount = withSizes.length;

      final blobs = await _store.list('blobs/');
      final referenced = await _referencedHashes();
      final blobHashes =
          blobs.map((k) => k.substring('blobs/'.length)).toSet();
      final orphanImages = blobHashes.difference(referenced).length;

      return SyncStats(
        totalBytes: totalBytes,
        objectCount: objectCount,
        referencedImages: referenced.length,
        orphanImages: orphanImages,
        metaFiles: objectCount - blobHashes.length,
      );
    } catch (e) {
      _log?.warning('S3', '获取存储统计失败: $e');
      // 网络错误时返回当前统计值（可能是部分结果）
      return SyncStats(
        totalBytes: totalBytes,
        objectCount: objectCount,
        referencedImages: 0,
        orphanImages: 0,
        metaFiles: objectCount,
      );
    }
  }

  /// 读取 manifest 中被引用的图片哈希集合。
  Future<Set<String>> _referencedHashes() async {
    final bytes = await _store.getBytes('sync/manifest.json');
    if (bytes == null) return {};
    final manifest = Manifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    return manifest.memes.values
        .where((e) => e.hash != null && e.hash!.isNotEmpty)
        .map((e) => e.hash!)
        .toSet();
  }

  // ---- 孤儿清理 ----

  /// 删除未被 manifest 引用的 blobs 与遗留旧 key，返回删除数量。
  Future<int> cleanupOrphans() async {
    if (!isConfigured) {
      throw StateError('S3 未配置');
    }
    final referenced = await _referencedHashes();
    var removed = 0;

    for (final key in await _store.list('blobs/')) {
      final hash = key.substring('blobs/'.length);
      if (!referenced.contains(hash)) {
        await _store.delete(key);
        removed++;
      }
    }

    for (final legacy
        in const ['snapshot-v1.json', 'data/memes.json', 'data/albums.json']) {
      if (await _store.exists(legacy)) {
        await _store.delete(legacy);
        removed++;
      }
    }

    for (final key in await _store.list('data/memes/')) {
      await _store.delete(key);
      removed++;
    }

    for (final key in await _store.list('memes/')) {
      await _store.delete(key);
      removed++;
    }

    return removed;
  }

  // ---- 清空 S3 数据 ----

  /// 删除 S3 bucket 中所有对象并重置同步状态
  Future<void> clearAllData({required String password}) async {
    final storedPw = await _secretStore.read(clearPasswordKey);
    if (storedPw == null || storedPw != password) {
      throw ArgumentError('清空密码验证失败，请检查密码是否正确');
    }

    final client = _getClient();
    final allKeys = <String>[];
    final results = client.listObjects(_config.bucket, recursive: true);
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
    await _secretStore.write(clearPasswordKey, password);
  }

  // ---- 清空密码管理 ----

  /// 检查是否已设置清空密码
  Future<bool> hasClearPassword() async {
    final pw = await _secretStore.read(clearPasswordKey);
    return pw != null && pw.isNotEmpty;
  }

  // ---- 资源释放 ----

  /// 释放资源（Provider 重建时调用）
  void dispose() {
    _client = null;
  }
}
