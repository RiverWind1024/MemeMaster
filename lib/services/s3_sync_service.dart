import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:minio/minio.dart';

import '../core/database/daos/sync_state_dao.dart';
import 'log_service.dart';
import 'object_store.dart';
import 's3_config.dart';
import 's3_keys.dart';
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
///
/// 引擎只有一个双向 LWW 入口：[incremental]。[uploadAll] / [downloadAll]
/// 只是为了兼容旧调用点而保留的别名，**它们并不做单向推送/拉取**，
/// 调用方（尤其是 CLI）必须显式告知用户这一点。
class S3SyncService {
  final ObjectStore _store;
  final SyncEngine _engine;
  final SyncStateDao _syncStateDao;
  final S3SecretStore _secretStore;
  final LogService? _log;
  S3Config _config = const S3Config();
  Minio? _client;

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
  ///
  /// 引擎无法在运行中中断，因此这里**不提供取消**：UI 上也不展示取消按钮，
  /// 避免出现一个点了没反应的控件。
  Stream<S3SyncProgress> incremental() async* {
    if (!isConfigured) {
      yield const S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: 'S3 未配置',
      );
      return;
    }
    yield const S3SyncProgress(
      status: S3SyncStatus.uploading,
      completed: 0,
      total: 1,
    );
    try {
      await _ensureBucket();
      // 把引擎的 onProgress 回调桥接到一个 StreamController，
      // 然后用 yield* 把这个流挂到 async* 函数体里——避免了「回调里
      // 直接 yield」的限制（async* 中 yield 是关键字，不能当函数引用）。
      final events = StreamController<S3SyncProgress>();
      SyncResult? captured;
      Object? capturedError;
      final syncDone = Completer<void>();
      _engine.onProgress = (p) {
        if (p.total <= 0) return;
        final status = p.phase == 'push'
            ? S3SyncStatus.uploading
            : S3SyncStatus.downloading;
        events.add(S3SyncProgress(
          status: status,
          completed: p.done,
          total: p.total,
        ));
      };
      // 启动 sync；同步结束后向 events 注入 idle 帧并关闭流。
      () async {
        try {
          captured = await _engine.sync();
          events.add(S3SyncProgress(
            status: S3SyncStatus.idle,
            completed: 1,
            total: 1,
            summary: captured == null
                ? ''
                : '完成：推送 ${captured!.pushed} / 拉取 ${captured!.pulled} / '
                    '删除 ${captured!.deleted} / '
                    '上传图片 ${captured!.imagesUploaded} / '
                    '下载图片 ${captured!.imagesDownloaded} / '
                    '缺图 ${captured!.imagesMissing} / '
                    '失败 ${captured!.failed}',
          ));
        } catch (e) {
          capturedError = e;
        } finally {
          _engine.onProgress = null;
          await events.close();
          syncDone.complete();
        }
      }();
      yield* events.stream;
      await syncDone.future;
      if (capturedError != null) throw capturedError!;
    } catch (e) {
      _engine.onProgress = null;
      _log?.error('S3 增量同步失败', e.toString());
      yield S3SyncProgress(
        status: S3SyncStatus.error,
        errorMessage: friendlyError(e),
      );
    }
  }

  /// 把底层异常转成对用户友好的提示。
  ///
  /// 区分「网络层故障」与「S3 / 配置错误」：前者通常瞬时且可重试，
  /// 后者一般需要修改设置。
  /// 友好的文案能告诉用户「之前的进度没丢，重试可继续」——LWW 协议
  /// 本身会让已成功条目在下次同步时被引擎跳过。
  static String friendlyError(Object e) {
    final s = e.toString();
    if (e is SocketException ||
        s.contains('SocketException') ||
        s.contains('Failed host lookup') ||
        s.contains('ClientException') ||
        s.contains('Connection refused') ||
        s.contains('Connection closed')) {
      return '网络连接失败：$s。'
          '已完成的同步结果已保留，恢复网络后再次点同步即可继续，无需从零开始。';
    }
    if (s.contains('AccessDenied') || s.contains('InvalidAccessKeyId')) {
      return 'S3 凭证或权限错误：$s。请检查设置中的 access key / secret key / region。';
    }
    return '同步失败: $s';
  }

  /// 全量上传的别名。
  ///
  /// 引擎为双向 LWW 同步，无法只做单向推送，因此与 [incremental] 等价。
  Stream<S3SyncProgress> uploadAll() => incremental();

  /// 全量下载的别名。
  ///
  /// 引擎为双向 LWW 同步，无法只做单向拉取，因此与 [incremental] 等价。
  Stream<S3SyncProgress> downloadAll() => incremental();

  // ---- 存储统计 ----

  /// 遍历 S3 bucket 统计存储用量与图片分项。
  /// 未配置 S3 时抛出异常（调用方应只在已配置时调用）。
  ///
  /// 使用单次列举（[ObjectStore.listWithSizes]）同时得到对象数与字节数，
  /// 并从同一份 key 集合派生 blob 集合，避免两次列举漂移。
  /// 若 manifest 缺失或不可读，无法确定引用集，此时将 `orphanImages`
  /// 保守地记为 `0`（不臆断全部 blob 为孤儿）。
  ///
  /// 网络/权限等错误会直接抛出，交由 UI 显示失败态——绝不返回一份
  /// 「看起来正常」的零值统计，那会让用户以为统计成功。
  Future<SyncStats> getStorageStats() async {
    if (!isConfigured) {
      throw StateError('S3 未配置');
    }
    final listing = await _store.listWithSizes('');
    var totalBytes = 0;
    for (final size in listing.values) {
      totalBytes += size;
    }
    final objectCount = listing.length;

    final blobHashes = listing.keys
        .where((k) => k.startsWith(kBlobPrefix))
        .map((k) => k.substring(kBlobPrefix.length))
        .toSet();
    final metaFiles = objectCount - blobHashes.length;

    final referenced = await _referencedHashes();
    if (referenced == null) {
      // manifest 缺失/不可读：不报告孤儿，避免误导用户误删。
      _log?.warning('S3', 'manifest 缺失或不可读，孤儿图片统计记为 0');
      return SyncStats(
        totalBytes: totalBytes,
        objectCount: objectCount,
        referencedImages: 0,
        orphanImages: 0,
        metaFiles: metaFiles,
      );
    }

    return SyncStats(
      totalBytes: totalBytes,
      objectCount: objectCount,
      referencedImages: referenced.length,
      orphanImages: blobHashes.difference(referenced).length,
      metaFiles: metaFiles,
    );
  }

  /// 读取 manifest 中被引用的图片哈希集合。
  ///
  /// 返回 `null` 表示 manifest 对象不存在（无法确定引用集）。
  /// [MinioObjectStore.getBytes] 只把真正的 not-found 转成 `null`，
  /// 瞬时 5xx 会直接抛出，因此调用方把 `null` 理解为「没有 manifest」
  /// 是安全的，但不能把它理解成「没有引用」。
  Future<Set<String>?> _referencedHashes() async {
    final bytes = await _store.getBytes(kManifestKey);
    if (bytes == null) return null;
    final manifest = Manifest.fromJson(
        jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
    return manifest.memes.values
        .where((e) => e.hash != null && e.hash!.isNotEmpty)
        .map((e) => e.hash!)
        .toSet();
  }

  // ---- 孤儿清理 ----

  /// 清理被阻止的原因（`null` 表示允许清理）。
  ///
  /// 空 manifest + 遗留 v1 键 = 该 bucket 还没完成 v1 → v2 迁移。
  /// 此时 manifest 里的 `referenced` 必然是空集，若继续清理会把**整个
  /// 遗留图库**（`memes/`、`data/`、`snapshot-v1.json`）连同所有 `blobs/*`
  /// 一并删掉。全新安装（本地图库为空 → 首轮同步写出空 manifest）点一下
  /// 「清理孤儿」就会触发，因此必须拒绝。
  ///
  /// 已知限制：删除操作不记录墓碑，若删除的实体在 manifest 中还有条目，
  /// 清理后其他设备的删除无法再传播（见 UI 与 CLI 帮助中的说明）。
  Future<String?> cleanupBlockedReason() async {
    if (!isConfigured) return 'S3 未配置';
    final referenced = await _referencedHashes();
    if (referenced == null) {
      return 'manifest 缺失或不可读，无法确定哪些图片仍被引用，已跳过清理';
    }
    // manifest 里一条实体都没有，但遗留 v1 键还在 → 尚未迁移。
    if (referenced.isEmpty && await _hasLegacyKeys()) {
      return '检测到遗留的 v1 数据但 manifest 为空，请先完成一次同步迁移后再清理';
    }
    return null;
  }

  /// 是否仍存在 v1 遗留对象。
  Future<bool> _hasLegacyKeys() async {
    for (final key in kLegacyObjectKeys) {
      if (await _store.exists(key)) return true;
    }
    for (final prefix in kLegacyPrefixes) {
      if ((await _store.list(prefix)).isNotEmpty) return true;
    }
    return false;
  }

  /// 删除未被 manifest 引用的 blobs 与遗留旧 key，返回删除数量。
  ///
  /// 保守策略：无法确定引用集（manifest 缺失/不可读）或 bucket 尚未完成
  /// v1 → v2 迁移时，一律**中止清理且不删除任何对象**，返回 `0`（记录 warning）。
  /// 详见 [cleanupBlockedReason]。
  Future<int> cleanupOrphans() async {
    if (!isConfigured) {
      throw StateError('S3 未配置');
    }
    final blocked = await cleanupBlockedReason();
    if (blocked != null) {
      _log?.warning('S3', '已中止孤儿清理（未删除任何对象）：$blocked');
      return 0;
    }
    // 上面的守卫刚刚确认过 manifest 可读；万一此刻读失败，宁可抛错也绝不
    // 把空引用集当成「没有引用」。
    final referenced = (await _referencedHashes())!;
    var removed = 0;

    for (final key in await _store.list(kBlobPrefix)) {
      final hash = key.substring(kBlobPrefix.length);
      if (!referenced.contains(hash)) {
        await _store.delete(key);
        removed++;
      }
    }

    for (final legacy in kLegacyObjectKeys) {
      if (await _store.exists(legacy)) {
        await _store.delete(legacy);
        removed++;
      }
    }

    for (final prefix in kLegacyPrefixes) {
      for (final key in await _store.list(prefix)) {
        await _store.delete(key);
        removed++;
      }
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
