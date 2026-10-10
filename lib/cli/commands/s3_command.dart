import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:minio/minio.dart';

import '../../services/object_store.dart';
import '../../services/s3_config.dart';
import '../../services/s3_secret_store.dart';
import '../../services/s3_sync_engine.dart';
import '../../services/s3_sync_service.dart';
import '../cli_context.dart';
import 'command.dart';

/// 纯内存版 S3SecretStore（CLI 用，不依赖 FlutterSecureStorage）。
///
/// S3 的 accessKey/secretKey 本身已由 [S3Config] 承载并入 cli_config.json，
/// 该 store 仅承载 [S3SyncService] 需要的"清空密码"等额外键，CLI 暂不暴露对应操作。
class _InMemoryS3SecretStore implements S3SecretStore {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }
}

/// s3 命令：连接测试 / 同步 / 上传 / 下载 / 统计。
///
/// 复用 [S3SyncService]（纯 Dart，依赖 minio 包，无 Flutter 依赖）。
class S3Command extends CliCommand {
  S3Command() : super(name: 's3', description: 'S3 同步相关操作');

  /// `upload` / `download` 的兼容别名提示。
  ///
  /// 引擎是双向 LWW 同步，没有单向推送/拉取：跑 `s3 download` 期望「从云端恢复」
  /// 实际上会把本地较新的数据也推上去，因此必须显式告知。
  static const _bidirectionalNotice =
      '提示：当前版本为双向 LWW 同步（本地较新数据也会上传），'
      'upload/download 等价于 sync。';

  @override
  bool get needsCliConfig => true;

  @override
  Future<int> run(CliContext context, ArgResults args) async {
    if (args.rest.isEmpty) {
      stderr.writeln(_usage());
      return 1;
    }
    final sub = args.rest.first;

    if (!context.s3Config.isValid) {
      stderr.writeln('S3 未配置，请先运行: mememaster config s3 '
          '--endpoint <url> --bucket <bucket> --access-key <key> --secret-key <key>');
      return 1;
    }

    final service = _buildService(context);
    switch (sub) {
      case 'test':
        return _test(context, service);
      case 'sync':
        return _consume(service.incremental(), '增量同步');
      case 'upload':
        stderr.writeln(_bidirectionalNotice);
        return _consume(service.uploadAll(), '全量上传');
      case 'download':
        stderr.writeln(_bidirectionalNotice);
        return _consume(service.downloadAll(), '全量下载');
      case 'stats':
        return _stats(context, service);
      default:
        stderr.writeln('未知 s3 子命令: $sub');
        stderr.writeln(_usage());
        return 1;
    }
  }

  static String _usage() => '''
用法: mememaster s3 <test|sync|upload|download|stats>
  test                测试 S3 连接
  sync                双向 LWW 同步（等价于 upload / download）
  upload / download   兼容别名，实际执行的是双向同步
  stats               统计 bucket 用量（总量 / 引用 / 孤儿 / 元数据）

已知限制：删除操作不写墓碑，清理后的删除无法再传播到其他设备。
$_bidirectionalNotice''';

  S3SyncService _buildService(CliContext context) {
    final config = context.s3Config;
    Minio client() => Minio(
          endPoint: config.endpoint,
          accessKey: config.accessKey,
          secretKey: config.secretKey,
          region: config.region,
          useSSL: config.useSsl,
          pathStyle: config.pathStyle,
        );
    final store = MinioObjectStore(client: client, bucket: config.bucket);
    final secretStore = _InMemoryS3SecretStore();
    final engine = SyncEngine(
      store: store,
      memeRepo: context.memeRepo,
      albumRepo: context.albumRepo,
      db: context.db,
      syncStateDao: context.db.syncStateDao,
      secretStore: secretStore,
      storage: context.storage,
    );
    final service = S3SyncService(
      store: store,
      engine: engine,
      syncStateDao: context.db.syncStateDao,
      secretStore: secretStore,
    );
    service.updateConfig(config);
    return service;
  }

  Future<int> _test(CliContext context, S3SyncService service) async {
    print('测试 S3 连接（${context.s3Config.endpoint}/${context.s3Config.bucket}）...');
    final ok = await service.testConnection();
    print(ok ? '连接成功' : '连接失败');
    return ok ? 0 : 1;
  }

  /// 消费同步进度流，错误打到 stderr，进度打到 stdout。
  Future<int> _consume(Stream<S3SyncProgress> stream, String label) async {
    var hadError = false;
    await for (final p in stream) {
      if (p.status == S3SyncStatus.error) {
        stderr.writeln('错误: ${p.errorMessage}');
        hadError = true;
      } else if (p.status == S3SyncStatus.uploading ||
          p.status == S3SyncStatus.downloading) {
        final verb = p.status == S3SyncStatus.uploading ? '上传' : '下载';
        print('$verb ${p.completed}/${p.total}');
      } else if (p.summary != null) {
        print(p.summary);
      }
    }
    print('$label${hadError ? '完成（有错误）' : '完成'}');
    return hadError ? 1 : 0;
  }

  Future<int> _stats(CliContext context, S3SyncService service) async {
    try {
      final stats = await service.getStorageStats();
      if (context.jsonOutput) {
        print(jsonEncode({
          'totalBytes': stats.totalBytes,
          'objectCount': stats.objectCount,
          'referencedImages': stats.referencedImages,
          'orphanImages': stats.orphanImages,
          'metaFiles': stats.metaFiles,
        }));
      } else {
        print('S3 存储用量: ${stats.totalBytes} 字节, ${stats.objectCount} 个对象');
        print('  引用图片: ${stats.referencedImages}');
        print('  孤儿图片: ${stats.orphanImages}');
        print('  元数据文件: ${stats.metaFiles}');
        final blocked = await service.cleanupBlockedReason();
        if (blocked != null) {
          print('  清理提示: $blocked');
        }
      }
      return 0;
    } catch (e) {
      stderr.writeln('获取 S3 统计失败: $e');
      return 1;
    }
  }
}
